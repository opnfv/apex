# Copyright 2012 OpenStack Foundation
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import abc
import eventlet
import netaddr
from oslo_config import cfg
from oslo_log import log as logging
import six

from neutron._i18n import _, _LE, _LI, _LW
from neutron.agent.common import ovs_lib
from neutron.agent.linux import ip_lib
from neutron.agent.linux import utils
from neutron.common import constants as n_const
from neutron.common import exceptions
from neutron.common import ipv6_utils


LOG = logging.getLogger(__name__)

OPTS = [
    cfg.StrOpt('ovs_integration_bridge',
               default='br-int',
               help=_('Name of Open vSwitch bridge to use')),
    cfg.BoolOpt('ovs_use_veth',
                default=False,
                help=_('Uses veth for an OVS interface or not. '
                       'Support kernels with limited namespace support '
                       '(e.g. RHEL 6.5) so long as ovs_use_veth is set to '
                       'True.')),
    cfg.IntOpt('network_device_mtu',
               deprecated_for_removal=True,
               help=_('MTU setting for device. This option will be removed in '
                      'Newton. Please use the system-wide segment_mtu setting '
                      'which the agents will take into account when wiring '
                      'VIFs.')),
]


@six.add_metaclass(abc.ABCMeta)
class LinuxInterfaceDriver(object):

    # from linux IF_NAMESIZE
    DEV_NAME_LEN = 14
    DEV_NAME_PREFIX = n_const.TAP_DEVICE_PREFIX

    def __init__(self, conf):
        self.conf = conf
        if self.conf.network_device_mtu:
            self._validate_network_device_mtu()

    def _validate_network_device_mtu(self):
        if (ipv6_utils.is_enabled() and
            self.conf.network_device_mtu < n_const.IPV6_MIN_MTU):
            LOG.error(_LE("IPv6 protocol requires a minimum MTU of "
                          "%(min_mtu)s, while the configured value is "
                          "%(current_mtu)s"), {'min_mtu': n_const.IPV6_MIN_MTU,
                          'current_mtu': self.conf.network_device_mtu})
            raise SystemExit(1)

    @property
    def use_gateway_ips(self):
        """Whether to use gateway IPs instead of unique IP allocations.

        In each place where the DHCP agent runs, and for each subnet for
        which DHCP is handling out IP addresses, the DHCP port needs -
        at the Linux level - to have an IP address within that subnet.
        Generally this needs to be a unique Neutron-allocated IP
        address, because the subnet's underlying L2 domain is bridged
        across multiple compute hosts and network nodes, and for HA
        there may be multiple DHCP agents running on that same bridged
        L2 domain.

        However, if the DHCP ports - on multiple compute/network nodes
        but for the same network - are _not_ bridged to each other,
        they do not need each to have a unique IP address.  Instead
        they can all share the same address from the relevant subnet.
        This works, without creating any ambiguity, because those
        ports are not all present on the same L2 domain, and because
        no data within the network is ever sent to that address.
        (DHCP requests are broadcast, and it is the network's job to
        ensure that such a broadcast will reach at least one of the
        available DHCP servers.  DHCP responses will be sent _from_
        the DHCP port address.)

        Specifically, for networking backends where it makes sense,
        the DHCP agent allows all DHCP ports to use the subnet's
        gateway IP address, and thereby to completely avoid any unique
        IP address allocation.  This behaviour is selected by running
        the DHCP agent with a configured interface driver whose
        'use_gateway_ips' property is True.

        When an operator deploys Neutron with an interface driver that
        makes use_gateway_ips True, they should also ensure that a
        gateway IP address is defined for each DHCP-enabled subnet,
        and that the gateway IP address doesn't change during the
        subnet's lifetime.
        """
        return False

    def init_l3(self, device_name, ip_cidrs, namespace=None,
                preserve_ips=None, clean_connections=False):
        """Set the L3 settings for the interface using data from the port.

        ip_cidrs: list of 'X.X.X.X/YY' strings
        preserve_ips: list of ip cidrs that should not be removed from device
        clean_connections: Boolean to indicate if we should cleanup connections
          associated to removed ips
        """
        preserve_ips = preserve_ips or []
        device = ip_lib.IPDevice(device_name, namespace=namespace)

        # The LLA generated by the operating system is not known to
        # Neutron, so it would be deleted if we added it to the 'previous'
        # list here
        default_ipv6_lla = ip_lib.get_ipv6_lladdr(device.link.address)
        previous = {addr['cidr'] for addr in device.addr.list(
            filters=['permanent'])} - {default_ipv6_lla}

        # add new addresses
        for ip_cidr in ip_cidrs:

            net = netaddr.IPNetwork(ip_cidr)
            # Convert to compact IPv6 address because the return values of
            # "ip addr list" are compact.
            if net.version == 6:
                ip_cidr = str(net)
            if ip_cidr in previous:
                previous.remove(ip_cidr)
                continue

            device.addr.add(ip_cidr)

        # clean up any old addresses
        for ip_cidr in previous:
            if ip_cidr not in preserve_ips:
                if clean_connections:
                    device.delete_addr_and_conntrack_state(ip_cidr)
                else:
                    device.addr.delete(ip_cidr)

    def init_router_port(self,
                         device_name,
                         ip_cidrs,
                         namespace,
                         preserve_ips=None,
                         extra_subnets=None,
                         clean_connections=False):
        """Set the L3 settings for a router interface using data from the port.

        ip_cidrs: list of 'X.X.X.X/YY' strings
        preserve_ips: list of ip cidrs that should not be removed from device
        clean_connections: Boolean to indicate if we should cleanup connections
          associated to removed ips
        extra_subnets: An iterable of cidrs to add as routes without address
        """
        LOG.debug("init_router_port: device_name(%s), namespace(%s)",
                  device_name, namespace)
        self.init_l3(device_name=device_name,
                     ip_cidrs=ip_cidrs,
                     namespace=namespace,
                     preserve_ips=preserve_ips or [],
                     clean_connections=clean_connections)

        device = ip_lib.IPDevice(device_name, namespace=namespace)

        # Manage on-link routes (routes without an associated address)
        new_onlink_cidrs = set(s['cidr'] for s in extra_subnets or [])

        v4_onlink = device.route.list_onlink_routes(n_const.IP_VERSION_4)
        v6_onlink = device.route.list_onlink_routes(n_const.IP_VERSION_6)
        existing_onlink_cidrs = set(r['cidr'] for r in v4_onlink + v6_onlink)

        for route in new_onlink_cidrs - existing_onlink_cidrs:
            LOG.debug("adding onlink route(%s)", route)
            device.route.add_onlink_route(route)
        for route in (existing_onlink_cidrs - new_onlink_cidrs -
                      set(preserve_ips or [])):
            LOG.debug("deleting onlink route(%s)", route)
            device.route.delete_onlink_route(route)

    def add_ipv6_addr(self, device_name, v6addr, namespace, scope='global'):
        device = ip_lib.IPDevice(device_name,
                                 namespace=namespace)
        net = netaddr.IPNetwork(v6addr)
        device.addr.add(str(net), scope)

    def delete_ipv6_addr(self, device_name, v6addr, namespace):
        device = ip_lib.IPDevice(device_name,
                                 namespace=namespace)
        device.delete_addr_and_conntrack_state(v6addr)

    def delete_ipv6_addr_with_prefix(self, device_name, prefix, namespace):
        """Delete the first listed IPv6 address that falls within a given
        prefix.
        """
        device = ip_lib.IPDevice(device_name, namespace=namespace)
        net = netaddr.IPNetwork(prefix)
        for address in device.addr.list(scope='global', filters=['permanent']):
            ip_address = netaddr.IPNetwork(address['cidr'])
            if ip_address in net:
                device.delete_addr_and_conntrack_state(address['cidr'])
                break

    def get_ipv6_llas(self, device_name, namespace):
        device = ip_lib.IPDevice(device_name,
                                 namespace=namespace)

        return device.addr.list(scope='link', ip_version=6)

    def check_bridge_exists(self, bridge):
        if not ip_lib.device_exists(bridge):
            raise exceptions.BridgeDoesNotExist(bridge=bridge)

    def get_device_name(self, port):
        return (self.DEV_NAME_PREFIX + port.id)[:self.DEV_NAME_LEN]

    @staticmethod
    def configure_ipv6_ra(namespace, dev_name):
        """Configure acceptance of IPv6 route advertisements on an intf."""
        # Learn the default router's IP address via RAs
        ip_lib.IPWrapper(namespace=namespace).netns.execute(
            ['sysctl', '-w', 'net.ipv6.conf.%s.accept_ra=2' % dev_name])

    @abc.abstractmethod
    def plug_new(self, network_id, port_id, device_name, mac_address,
                 bridge=None, namespace=None, prefix=None, mtu=None):
        """Plug in the interface only for new devices that don't exist yet."""

    def plug(self, network_id, port_id, device_name, mac_address,
             bridge=None, namespace=None, prefix=None, mtu=None):
        if not ip_lib.device_exists(device_name,
                                    namespace=namespace):
            try:
                self.plug_new(network_id, port_id, device_name, mac_address,
                              bridge, namespace, prefix, mtu)
            except TypeError:
                self.plug_new(network_id, port_id, device_name, mac_address,
                              bridge, namespace, prefix)
        else:
            LOG.info(_LI("Device %s already exists"), device_name)

    @abc.abstractmethod
    def unplug(self, device_name, bridge=None, namespace=None, prefix=None):
        """Unplug the interface."""

    @property
    def bridged(self):
        """Whether the DHCP port is bridged to the VM TAP interfaces.

        When the DHCP port is bridged to the TAP interfaces for the
        VMs for which it is providing DHCP service - as is the case
        for most Neutron network implementations - the DHCP server
        only needs to listen on the DHCP port, and will still receive
        DHCP requests from all the relevant VMs.

        If the DHCP port is not bridged to the relevant VM TAP
        interfaces, the DHCP server needs to listen explicitly on
        those TAP interfaces, and to treat those as aliases of the
        DHCP port where the IP subnet is defined.
        """
        return True


class NullDriver(LinuxInterfaceDriver):
    def plug_new(self, network_id, port_id, device_name, mac_address,
                 bridge=None, namespace=None, prefix=None, mtu=None):
        pass

    def unplug(self, device_name, bridge=None, namespace=None, prefix=None):
        pass

class NSDriver(LinuxInterfaceDriver):
    """Device independent driver enabling creation of a non device specific
    interface in network spaces.  Attachment to the device is not performed.
    """
    MAX_TIME_FOR_DEVICE_EXISTENCE = 30

    @classmethod
    def _device_is_created_in_time(cls, device_name):
        """See if device is created, within time limit."""
        attempt = 0
        while attempt < NSDriver.MAX_TIME_FOR_DEVICE_EXISTENCE:
            if ip_lib.device_exists(device_name):
                return True
            attempt += 1
            eventlet.sleep(1)
        LOG.error(_LE("Device %(dev)s was not created in %(time)d seconds"),
                  {'dev': device_name,
                   'time': NSDriver.MAX_TIME_FOR_DEVICE_EXISTENCE})
        return False

    def _configure_mtu(self, ns_dev, mtu=None):
        # Need to set MTU, after added to namespace. See review
        # https://review.openstack.org/327651
        try:
            # Note: network_device_mtu will be deprecated in future
            mtu_override = self.conf.network_device_mtu
        except cfg.NoSuchOptError:
            LOG.warning(_LW("Config setting for MTU deprecated - any "
                            "override will be ignored."))
            mtu_override = None
        if mtu_override:
            mtu = mtu_override
            LOG.debug("Overriding MTU to %d", mtu)
        if mtu:
            ns_dev.link.set_mtu(mtu)
        else:
            LOG.debug("No MTU provided - skipping setting value")

    def plug(self, network_id, port_id, device_name, mac_address,
             bridge=None, namespace=None, prefix=None, mtu=None):

        # Overriding this, we still want to add an existing device into the
        # namespace.
        self.plug_new(network_id, port_id, device_name, mac_address,
                      bridge, namespace, prefix, mtu)

    def plug_new(self, network_id, port_id, device_name, mac_address,
                 bridge=None, namespace=None, prefix=None, mtu=None):

        ip = ip_lib.IPWrapper()
        ns_dev = ip.device(device_name)

        LOG.debug("Plugging dev: '%s' into namespace: '%s' ",
                  device_name, namespace)

        # Wait for device creation
        if not self._device_is_created_in_time(device_name):
            return

        ns_dev.link.set_address(mac_address)

        if namespace:
            namespace_obj = ip.ensure_namespace(namespace)
            namespace_obj.add_device_to_namespace(ns_dev)

        self._configure_mtu(ns_dev, mtu)

        ns_dev.link.set_up()

    def unplug(self, device_name, bridge=None, namespace=None, prefix=None):
        # Device removal is done externally. Just remove the namespace
        LOG.debug("Removing namespace: '%s'", namespace)
        ip_lib.IPWrapper(namespace).garbage_collect_namespace()


class OVSInterfaceDriver(LinuxInterfaceDriver):
    """Driver for creating an internal interface on an OVS bridge."""

    DEV_NAME_PREFIX = n_const.TAP_DEVICE_PREFIX

    def __init__(self, conf):
        super(OVSInterfaceDriver, self).__init__(conf)
        if self.conf.ovs_use_veth:
            self.DEV_NAME_PREFIX = 'ns-'

    def _get_tap_name(self, dev_name, prefix=None):
        if self.conf.ovs_use_veth:
            dev_name = dev_name.replace(prefix or self.DEV_NAME_PREFIX,
                                        n_const.TAP_DEVICE_PREFIX)
        return dev_name

    def _ovs_add_port(self, bridge, device_name, port_id, mac_address,
                      internal=True):
        attrs = [('external_ids', {'iface-id': port_id,
                                   'iface-status': 'active',
                                   'attached-mac': mac_address})]
        if internal:
            attrs.insert(0, ('type', 'internal'))

        ovs = ovs_lib.OVSBridge(bridge)
        ovs.replace_port(device_name, *attrs)

    def plug_new(self, network_id, port_id, device_name, mac_address,
                 bridge=None, namespace=None, prefix=None, mtu=None):
        """Plug in the interface."""
        if not bridge:
            bridge = self.conf.ovs_integration_bridge

        self.check_bridge_exists(bridge)

        ip = ip_lib.IPWrapper()
        tap_name = self._get_tap_name(device_name, prefix)

        if self.conf.ovs_use_veth:
            # Create ns_dev in a namespace if one is configured.
            root_dev, ns_dev = ip.add_veth(tap_name,
                                           device_name,
                                           namespace2=namespace)
            root_dev.disable_ipv6()
        else:
            ns_dev = ip.device(device_name)

        internal = not self.conf.ovs_use_veth
        self._ovs_add_port(bridge, tap_name, port_id, mac_address,
                           internal=internal)

        ns_dev.link.set_address(mac_address)

        # Add an interface created by ovs to the namespace.
        if not self.conf.ovs_use_veth and namespace:
            namespace_obj = ip.ensure_namespace(namespace)
            namespace_obj.add_device_to_namespace(ns_dev)

        # NOTE(ihrachys): the order here is significant: we must set MTU after
        # the device is moved into a namespace, otherwise OVS bridge does not
        # allow to set MTU that is higher than the least of all device MTUs on
        # the bridge
        mtu = self.conf.network_device_mtu or mtu
        if mtu:
            ns_dev.link.set_mtu(mtu)
            if self.conf.ovs_use_veth:
                root_dev.link.set_mtu(mtu)
        else:
            LOG.warning(_LW("No MTU configured for port %s"), port_id)

        ns_dev.link.set_up()
        if self.conf.ovs_use_veth:
            root_dev.link.set_up()

    def unplug(self, device_name, bridge=None, namespace=None, prefix=None):
        """Unplug the interface."""
        if not bridge:
            bridge = self.conf.ovs_integration_bridge

        tap_name = self._get_tap_name(device_name, prefix)
        self.check_bridge_exists(bridge)
        ovs = ovs_lib.OVSBridge(bridge)

        try:
            ovs.delete_port(tap_name)
            if self.conf.ovs_use_veth:
                device = ip_lib.IPDevice(device_name, namespace=namespace)
                device.link.delete()
                LOG.debug("Unplugged interface '%s'", device_name)
        except RuntimeError:
            LOG.error(_LE("Failed unplugging interface '%s'"),
                      device_name)


class IVSInterfaceDriver(LinuxInterfaceDriver):
    """Driver for creating an internal interface on an IVS bridge."""

    DEV_NAME_PREFIX = n_const.TAP_DEVICE_PREFIX

    def __init__(self, conf):
        super(IVSInterfaceDriver, self).__init__(conf)
        self.DEV_NAME_PREFIX = 'ns-'

    def _get_tap_name(self, dev_name, prefix=None):
        dev_name = dev_name.replace(prefix or self.DEV_NAME_PREFIX,
                                    n_const.TAP_DEVICE_PREFIX)
        return dev_name

    def _ivs_add_port(self, device_name, port_id, mac_address):
        cmd = ['ivs-ctl', 'add-port', device_name]
        utils.execute(cmd, run_as_root=True)

    def plug_new(self, network_id, port_id, device_name, mac_address,
                 bridge=None, namespace=None, prefix=None, mtu=None):
        """Plug in the interface."""
        ip = ip_lib.IPWrapper()
        tap_name = self._get_tap_name(device_name, prefix)

        root_dev, ns_dev = ip.add_veth(tap_name, device_name)
        root_dev.disable_ipv6()

        self._ivs_add_port(tap_name, port_id, mac_address)

        ns_dev = ip.device(device_name)
        ns_dev.link.set_address(mac_address)

        mtu = self.conf.network_device_mtu or mtu
        if mtu:
            ns_dev.link.set_mtu(mtu)
            root_dev.link.set_mtu(mtu)
        else:
            LOG.warning(_LW("No MTU configured for port %s"), port_id)

        if namespace:
            namespace_obj = ip.ensure_namespace(namespace)
            namespace_obj.add_device_to_namespace(ns_dev)

        ns_dev.link.set_up()
        root_dev.link.set_up()

    def unplug(self, device_name, bridge=None, namespace=None, prefix=None):
        """Unplug the interface."""
        tap_name = self._get_tap_name(device_name, prefix)
        try:
            cmd = ['ivs-ctl', 'del-port', tap_name]
            utils.execute(cmd, run_as_root=True)
            device = ip_lib.IPDevice(device_name, namespace=namespace)
            device.link.delete()
            LOG.debug("Unplugged interface '%s'", device_name)
        except RuntimeError:
            LOG.error(_LE("Failed unplugging interface '%s'"),
                      device_name)


class BridgeInterfaceDriver(LinuxInterfaceDriver):
    """Driver for creating bridge interfaces."""

    DEV_NAME_PREFIX = 'ns-'

    def plug_new(self, network_id, port_id, device_name, mac_address,
                 bridge=None, namespace=None, prefix=None, mtu=None):
        """Plugin the interface."""
        ip = ip_lib.IPWrapper()

        # Enable agent to define the prefix
        tap_name = device_name.replace(prefix or self.DEV_NAME_PREFIX,
                                       n_const.TAP_DEVICE_PREFIX)
        # Create ns_veth in a namespace if one is configured.
        root_veth, ns_veth = ip.add_veth(tap_name, device_name,
                                         namespace2=namespace)
        root_veth.disable_ipv6()
        ns_veth.link.set_address(mac_address)

        mtu = self.conf.network_device_mtu or mtu
        if mtu:
            root_veth.link.set_mtu(mtu)
            ns_veth.link.set_mtu(mtu)
        else:
            LOG.warning(_LW("No MTU configured for port %s"), port_id)

        root_veth.link.set_up()
        ns_veth.link.set_up()

    def unplug(self, device_name, bridge=None, namespace=None, prefix=None):
        """Unplug the interface."""
        device = ip_lib.IPDevice(device_name, namespace=namespace)
        try:
            device.link.delete()
            LOG.debug("Unplugged interface '%s'", device_name)
        except RuntimeError:
            LOG.error(_LE("Failed unplugging interface '%s'"),
                      device_name)
