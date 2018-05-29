##############################################################################
# Copyright (c) 2016 Feng Pan (fpan@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import ipaddress
import logging
from copy import copy

import yaml

from apex.common import utils
from apex.common.constants import (
    CONTROLLER,
    COMPUTE,
    ROLES,
    DOMAIN_NAME,
    DNS_SERVERS,
    NTP_SERVER,
    ADMIN_NETWORK,
    EXTERNAL_NETWORK,
    OPNFV_NETWORK_TYPES,
)
from apex.network import ip_utils


class NetworkSettings(dict):
    """
    This class parses APEX network settings yaml file into an object. It
    generates or detects all missing fields for deployment.

    The resulting object will be used later to generate network environment
    file as well as configuring post deployment networks.
    """
    def __init__(self, filename):
        init_dict = {}
        if isinstance(filename, str):
            with open(filename, 'r') as network_settings_file:
                init_dict = yaml.safe_load(network_settings_file)
        else:
            # assume input is a dict to build from
            init_dict = filename
        super().__init__(init_dict)

        if 'apex' in self:
            # merge two dicts Non-destructively
            def merge(pri, sec):
                for key, val in sec.items():
                    if key in pri:
                        if isinstance(val, dict):
                            merge(pri[key], val)
                        # else
                        # do not overwrite what's already there
                    else:
                        pri[key] = val
            # merge the apex specific config into the first class settings
            merge(self, copy(self['apex']))

        self.enabled_network_list = []
        self.nics = {COMPUTE: {}, CONTROLLER: {}}
        self.nics_specified = {COMPUTE: False, CONTROLLER: False}
        self._validate_input()

    def get_network(self, network):
        if network == EXTERNAL_NETWORK and self['networks'][network]:
            for net in self['networks'][network]:
                if 'public' in net:
                    return net

            raise NetworkSettingsException("The external network, "
                                           "'public', should be defined "
                                           "when external networks are "
                                           "enabled")
        else:
            return self['networks'][network]

    def _validate_input(self):
        """
        Validates the network settings file and populates all fields.

        NetworkSettingsException will be raised if validation fails.
        """
        if not self['networks'].get(ADMIN_NETWORK, {}).get('enabled', False):
            raise NetworkSettingsException("You must enable admin network "
                                           "and configure it explicitly or "
                                           "use auto-detection")

        for network in OPNFV_NETWORK_TYPES:
            if network in self['networks']:
                _network = self.get_network(network)
                if _network.get('enabled', True):
                    logging.info("{} enabled".format(network))
                    self._config_required_settings(network)
                    nicmap = _network['nic_mapping']
                    self._validate_overcloud_nic_order(network)
                    iface = nicmap[CONTROLLER]['members'][0]
                    self._config_ip_range(network=network,
                                          interface=iface,
                                          ip_range='overcloud_ip_range',
                                          start_offset=21, end_offset=21)
                    self.enabled_network_list.append(network)
                    # TODO self._config_optional_settings(network)
                else:
                    logging.info("{} disabled, will collapse with "
                                 "admin network".format(network))
            else:
                logging.info("{} is not in specified, will collapse with "
                             "admin network".format(network))

        if 'dns-domain' not in self:
            self['domain_name'] = DOMAIN_NAME
        else:
            self['domain_name'] = self['dns-domain']
        self['dns_servers'] = self.get('dns_nameservers', DNS_SERVERS)
        self['ntp_servers'] = self.get('ntp', NTP_SERVER)

    def _validate_overcloud_nic_order(self, network):
        """
        Detects if nic order is specified per profile (compute/controller)
        for network

        If nic order is specified in a network for a profile, it should be
        specified for every network with that profile other than admin network

        Duplicate nic names are also not allowed across different networks

        :param network: network to detect if nic order present
        :return: None
        """
        for role in ROLES:
            _network = self.get_network(network)
            _nicmap = _network.get('nic_mapping', {})
            _role = _nicmap.get(role, {})
            interfaces = _role.get('members', [])

            if interfaces:
                interface = interfaces[0]
                if not isinstance(_role.get('vlan', 'native'), int) and \
                   any(y == interface for x, y in self.nics[role].items()):
                    raise NetworkSettingsException(
                        "Duplicate {} already specified for "
                        "another network".format(interface))
                self.nics[role][network] = interface
                self.nics_specified[role] = True
                logging.info("{} nic order specified for network {"
                             "}".format(role, network))
            else:
                raise NetworkSettingsException(
                    "Interface members are not supplied for {} network "
                    "for the {} role. Please add nic assignments"
                    "".format(network, role))

    def _config_required_settings(self, network):
        """
        Configures either CIDR or bridged_interface setting

        cidr takes precedence if both cidr and bridged_interface are specified
        for a given network.

        When using bridged_interface, we will detect network setting on the
        given NIC in the system. The resulting config in settings object will
        be an ipaddress.network object, replacing the NIC name.
        """
        _network = self.get_network(network)
        # if vlan not defined then default it to native
        for role in ROLES:
            if network is not ADMIN_NETWORK:
                if 'vlan' not in _network['nic_mapping'][role]:
                    _network['nic_mapping'][role]['vlan'] = 'native'
            else:
                # ctlplane network must be native
                _network['nic_mapping'][role]['vlan'] = 'native'

        cidr = _network.get('cidr')

        if cidr:
            cidr = ipaddress.ip_network(_network['cidr'])
            _network['cidr'] = cidr
            logging.info("{}_cidr: {}".format(network, cidr))
        elif 'installer_vm' in _network:
            ucloud_if_list = _network['installer_vm']['members']
            # If cidr is not specified, we need to know if we should find
            # IPv6 or IPv4 address on the interface
            ip = ipaddress.ip_address(_network['installer_vm']['ip'])
            nic_if = ip_utils.get_interface(ucloud_if_list[0], ip.version)
            if nic_if:
                logging.info("{}_bridged_interface: {}".
                             format(network, nic_if))
            else:
                raise NetworkSettingsException(
                    "Auto detection failed for {}: Unable to find valid "
                    "ip for interface {}".format(network, ucloud_if_list[0]))

        else:
            raise NetworkSettingsException(
                "Auto detection failed for {}: either installer_vm "
                "members or cidr must be specified".format(network))

        # undercloud settings
        if network == ADMIN_NETWORK:
            provisioner_ip = _network['installer_vm']['ip']
            iface = _network['installer_vm']['members'][0]
            if not provisioner_ip:
                _network['installer_vm']['ip'] = self._gen_ip(network, 1)
            self._config_ip_range(network=network, interface=iface,
                                  ip_range='dhcp_range',
                                  start_offset=2, count=9)
            self._config_ip_range(network=network, interface=iface,
                                  ip_range='introspection_range',
                                  start_offset=11, count=9)
        elif network == EXTERNAL_NETWORK:
            provisioner_ip = _network['installer_vm']['ip']
            iface = _network['installer_vm']['members'][0]
            if not provisioner_ip:
                _network['installer_vm']['ip'] = self._gen_ip(network, 1)
            self._config_ip_range(network=network, interface=iface,
                                  ip_range='floating_ip_range',
                                  end_offset=2, count=20)

            gateway = _network['gateway']
            interface = _network['installer_vm']['ip']
            self._config_gateway(network, gateway, interface)

    def _config_ip_range(self, network, ip_range, interface=None,
                         start_offset=None, end_offset=None, count=None):
        """
        Configures IP range for a given setting.
        If the setting is already specified, no change will be made.
        The spec for start_offset, end_offset and count are identical to
        ip_utils.get_ip_range.
        """
        _network = self.get_network(network)
        if ip_range not in _network:
            cidr = _network.get('cidr')
            _ip_range = ip_utils.get_ip_range(start_offset=start_offset,
                                              end_offset=end_offset,
                                              count=count,
                                              cidr=cidr,
                                              interface=interface)
            _network[ip_range] = _ip_range.split(',')

        logging.info("Config IP Range: {} {}".format(network, ip_range))

    def _gen_ip(self, network, offset):
        """
        Generate and ip offset within the given network
        """
        _network = self.get_network(network)
        cidr = _network.get('cidr')
        ip = ip_utils.get_ip(offset, cidr)
        logging.info("Config IP: {} {}".format(network, ip))
        return ip

    def _config_optional_settings(self, network):
        """
        Configures optional settings:
        - admin_network:
            - provisioner_ip
            - dhcp_range
            - introspection_range
        - public_network:
            - provisioner_ip
            - floating_ip_range
            - gateway
        """
        if network == ADMIN_NETWORK:
            # FIXME: _config_ip  function does not exist!
            self._config_ip(network, None, 'provisioner_ip', 1)
            self._config_ip_range(network=network,
                                  ip_range='dhcp_range',
                                  start_offset=2, count=9)
            self._config_ip_range(network=network,
                                  ip_range='introspection_range',
                                  start_offset=11, count=9)
        elif network == EXTERNAL_NETWORK:
            # FIXME: _config_ip  function does not exist!
            self._config_ip(network, None, 'provisioner_ip', 1)
            self._config_ip_range(network=network,
                                  ip_range='floating_ip_range',
                                  end_offset=2, count=20)
            self._config_gateway(network)

    def _config_gateway(self, network, gateway, interface):
        """
        Configures gateway setting for a given network.

        If cidr is specified, we always use the first address in the address
        space for gateway. Otherwise, we detect the system gateway.
        """
        _network = self.get_network(network)
        if not gateway:
            cidr = _network.get('cidr')
            if cidr:
                _gateway = ip_utils.get_ip(1, cidr)
            else:
                _gateway = ip_utils.find_gateway(interface)

            if _gateway:
                _network['gateway'] = _gateway
            else:
                raise NetworkSettingsException("Failed to set gateway")

        logging.info("Config Gateway: {} {}".format(network, gateway))

    def get_ip_addr_family(self,):
        """
        Returns IP address family for current deployment.

        If any enabled network has IPv6 CIDR, the deployment is classified as
        IPv6.
        """
        return max([
            ipaddress.ip_network(self.get_network(n)['cidr']).version
            for n in self.enabled_network_list])


class NetworkSettingsException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
            return self.value
