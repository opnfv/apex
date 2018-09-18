##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import libvirt
import logging
import os
import platform
import shutil
import subprocess
import time

from apex.virtual import utils as virt_utils
from apex.virtual import configure_vm as vm_lib
from apex.common import constants
from apex.common import utils


class ApexUndercloudException(Exception):
    pass


class Undercloud:
    """
    This class represents an Apex Undercloud VM
    """
    def __init__(self, image_path, template_path,
                 root_pw=None, external_network=False,
                 image_name='undercloud.qcow2',
                 os_version=constants.DEFAULT_OS_VERSION):
        self.ip = None
        self.os_version = os_version
        self.root_pw = root_pw
        self.external_net = external_network
        self.volume = os.path.join(constants.LIBVIRT_VOLUME_PATH,
                                   'undercloud.qcow2')
        self.image_path = image_path
        self.image_name = image_name
        self.template_path = template_path
        self.vm = None
        if Undercloud._get_vm():
            logging.error("Undercloud VM already exists.  Please clean "
                          "before creating")
            raise ApexUndercloudException("Undercloud VM already exists!")
        self.create()

    @staticmethod
    def _get_vm():
        conn = libvirt.open('qemu:///system')
        try:
            vm = conn.lookupByName('undercloud')
            return vm
        except libvirt.libvirtError:
            logging.debug("No undercloud VM exists")

    def create(self):
        networks = ['admin']
        if self.external_net:
            networks.append('external')
        console = 'ttyAMA0' if platform.machine() == 'aarch64' else 'ttyS0'
        root = 'vda' if platform.machine() == 'aarch64' else 'sda'

        self.vm = vm_lib.create_vm(name='undercloud',
                                   image=self.volume,
                                   baremetal_interfaces=networks,
                                   direct_boot='overcloud-full',
                                   kernel_args=['console={}'.format(console),
                                                'root=/dev/{}'.format(root)],
                                   default_network=True,
                                   template_dir=self.template_path)
        self.setup_volumes()
        self.inject_auth()

    @staticmethod
    def _get_ip(vm):
        ip_out = vm.interfaceAddresses(
            libvirt.VIR_DOMAIN_INTERFACE_ADDRESSES_SRC_LEASE, 0)
        if ip_out:
            for (name, val) in ip_out.items():
                for ipaddr in val['addrs']:
                    if ipaddr['type'] == libvirt.VIR_IP_ADDR_TYPE_IPV4:
                        return ipaddr['addr']

    def _set_ip(self):
        ip = self._get_ip(self.vm)
        if ip:
            self.ip = ip
            return True

    @staticmethod
    def get_ip():
        vm = Undercloud._get_vm()
        return Undercloud._get_ip(vm)

    def start(self):
        """
        Start Undercloud VM
        :return: None
        """
        if self.vm.isActive():
            logging.info("Undercloud already started")
        else:
            logging.info("Starting undercloud")
            self.vm.create()
            # give 10 seconds to come up
            time.sleep(10)
        # set IP
        for x in range(5):
            if self._set_ip():
                logging.info("Undercloud started.  IP Address: {}".format(
                    self.ip))
                break
            logging.debug("Did not find undercloud IP in {} "
                          "attempts...".format(x))
            time.sleep(10)
        else:
            logging.error("Cannot find IP for Undercloud")
            raise ApexUndercloudException(
                "Unable to find IP for undercloud.  Check if VM booted "
                "correctly")

    def detect_nat(self, net_settings):
        if self.external_net:
            net = net_settings['networks'][constants.EXTERNAL_NETWORK][0]
        else:
            net = net_settings['networks'][constants.ADMIN_NETWORK]
        if net['gateway'] == net['installer_vm']['ip']:
            return True
        else:
            return False

    def configure(self, net_settings, deploy_settings,
                  playbook, apex_temp_dir, virtual_oc=False):
        """
        Configures undercloud VM
        :param net_settings: Network settings for deployment
        :param deploy_settings: Deployment settings for deployment
        :param playbook: playbook to use to configure undercloud
        :param apex_temp_dir: temporary apex directory to hold configs/logs
        :param virtual_oc: Boolean to determine if overcloud is virt
        :return: None
        """

        logging.info("Configuring Undercloud...")
        # run ansible
        ansible_vars = Undercloud.generate_config(net_settings,
                                                  deploy_settings)
        ansible_vars['apex_temp_dir'] = apex_temp_dir

        ansible_vars['nat'] = self.detect_nat(net_settings)
        try:
            utils.run_ansible(ansible_vars, playbook, host=self.ip,
                              user='stack')
        except subprocess.CalledProcessError:
            logging.error(
                "Failed to install undercloud..."
                "please check log: {}".format(os.path.join(
                    apex_temp_dir, 'apex-undercloud-install.log')))
            raise ApexUndercloudException('Failed to install undercloud')
        logging.info("Undercloud installed!")

    def setup_volumes(self):
        for img_file in ('overcloud-full.vmlinuz', 'overcloud-full.initrd',
                         self.image_name):
            src_img = os.path.join(self.image_path, img_file)
            if img_file == self.image_name:
                dest_img = os.path.join(constants.LIBVIRT_VOLUME_PATH,
                                        'undercloud.qcow2')
            else:
                dest_img = os.path.join(constants.LIBVIRT_VOLUME_PATH,
                                        img_file)
            if not os.path.isfile(src_img):
                raise ApexUndercloudException(
                    "Required source file does not exist:{}".format(src_img))
            if os.path.exists(dest_img):
                os.remove(dest_img)
            shutil.copyfile(src_img, dest_img)
            shutil.chown(dest_img, user='qemu', group='qemu')
            os.chmod(dest_img, 0o0744)
        # TODO(trozet):check if resize needed right now size is 50gb
        # there is a lib called vminspect which has some dependencies and is
        # not yet available in pip.  Consider switching to this lib later.

    def inject_auth(self):
        virt_ops = list()
        # virt-customize keys/pws
        if self.root_pw:
            pw_op = "password:{}".format(self.root_pw)
            virt_ops.append({constants.VIRT_PW: pw_op})
        # ssh key setup
        virt_ops.append({constants.VIRT_RUN_CMD:
                        'mkdir -p /root/.ssh'})
        virt_ops.append({constants.VIRT_UPLOAD:
                         '/root/.ssh/id_rsa.pub:/root/.ssh/authorized_keys'})
        run_cmds = [
            'chmod 600 /root/.ssh/authorized_keys',
            'restorecon /root/.ssh/authorized_keys',
            'cp /root/.ssh/authorized_keys /home/stack/.ssh/',
            'chown stack:stack /home/stack/.ssh/authorized_keys',
            'chmod 600 /home/stack/.ssh/authorized_keys'
        ]
        for cmd in run_cmds:
            virt_ops.append({constants.VIRT_RUN_CMD: cmd})
        virt_utils.virt_customize(virt_ops, self.volume)

    @staticmethod
    def generate_config(ns, ds):
        """
        Generates a dictionary of settings for configuring undercloud
        :param ns: network settings to derive undercloud settings
        :param ds: deploy settings to derive undercloud settings
        :return: dictionary of settings
        """

        ns_admin = ns['networks']['admin']
        intro_range = ns['apex']['networks']['admin']['introspection_range']
        config = dict()
        # Check if this is an ARM deployment
        config['aarch64'] = platform.machine() == 'aarch64'
        # Configuration for undercloud.conf
        config['undercloud_config'] = [
            "enable_ui false",
            "undercloud_update_packages false",
            "undercloud_debug false",
            "inspection_extras false",
            "ipxe_enabled {}".format(
                str(ds['global_params'].get('ipxe', True) and
                    not config['aarch64'])),
            "undercloud_hostname undercloud.{}".format(ns['dns-domain']),
            "local_ip {}/{}".format(str(ns_admin['installer_vm']['ip']),
                                    str(ns_admin['cidr']).split('/')[1]),
            "network_gateway {}".format(str(ns_admin['installer_vm']['ip'])),
            "network_cidr {}".format(str(ns_admin['cidr'])),
            "dhcp_start {}".format(str(ns_admin['dhcp_range'][0])),
            "dhcp_end {}".format(str(ns_admin['dhcp_range'][1])),
            "inspection_iprange {}".format(','.join(intro_range)),
            "generate_service_certificate false",
            "undercloud_ntp_servers {}".format(str(ns['ntp'][0]))
        ]

        config['ironic_config'] = [
            "disk_utils iscsi_verify_attempts 30",
            "disk_partitioner check_device_max_retries 40"
        ]

        config['nova_config'] = [
            "dns_domain {}".format(ns['dns-domain']),
            "dhcp_domain {}".format(ns['dns-domain'])
        ]

        config['neutron_config'] = [
            "dns_domain {}".format(ns['dns-domain']),
        ]
        # FIXME(trozet): possible bug here with not using external network
        ns_external = ns['networks']['external'][0]
        config['external_network'] = {
            "vlan": ns_external['installer_vm']['vlan'],
            "ip": ns_external['installer_vm']['ip'],
            "prefix": str(ns_external['cidr']).split('/')[1],
            "enabled": ns_external['enabled']
        }
        # We will NAT external network if it is enabled. If external network
        # is IPv6, we will NAT admin network in case we need IPv4 connectivity
        # for things like DNS server.
        if 'external' in ns.enabled_network_list and \
                ns_external['cidr'].version == 4:
            nat_cidr = ns_external['cidr']
        else:
            nat_cidr = ns['networks']['admin']['cidr']
        config['nat_cidr'] = str(nat_cidr)
        if nat_cidr.version == 6:
            config['nat_network_ipv6'] = True
        else:
            config['nat_network_ipv6'] = False
        config['http_proxy'] = ns.get('http_proxy', '')
        config['https_proxy'] = ns.get('https_proxy', '')

        return config

    def _update_delorean_repo(self):
        if utils.internet_connectivity():
            logging.info('Updating delorean repo on Undercloud')
            delorean_repo = (
                "https://trunk.rdoproject.org/centos7-{}"
                "/current-tripleo/delorean.repo".format(self.os_version))
            cmd = ("curl -L -f -o "
                   "/etc/yum.repos.d/deloran.repo {}".format(delorean_repo))
            try:
                virt_utils.virt_customize([{constants.VIRT_RUN_CMD: cmd}],
                                          self.volume)
            except Exception:
                logging.warning("Failed to download and update delorean repo "
                                "for Undercloud")
