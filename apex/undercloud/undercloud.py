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
import shutil
import time

from apex.virtual import virtual_utils as virt_utils
from apex.virtual import configure_vm as vm_lib
from apex.common import constants
from apex.common import utils


class ApexUndercloudException(Exception):
    pass


class Undercloud:
    """
    This class represents an Apex Undercloud VM
    """
    def __init__(self, image_path, root_pw=None, external_network=False):
        self.ip = None
        self.root_pw = root_pw
        self.external_net = external_network
        self.volume = os.path.join(constants.LIBVIRT_VOLUME_PATH,
                                   'undercloud.qcow2')
        self.image_path = image_path
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
        self.vm = vm_lib.create_vm(name='undercloud',
                                   image=self.volume,
                                   baremetal_interfaces=networks,
                                   direct_boot='overcloud-full',
                                   kernel_args=['console=ttyS0',
                                                'root=/dev/sda'],
                                   default_network=True)
        self.setup_volumes()
        self.inject_auth()

    def _set_ip(self):
        ip_out = self.vm.interfaceAddresses(
            libvirt.VIR_DOMAIN_INTERFACE_ADDRESSES_SRC_LEASE, 0)
        if ip_out:
            for (name, val) in ip_out.items():
                for ipaddr in val['addrs']:
                    if ipaddr['type'] == libvirt.VIR_IP_ADDR_TYPE_IPV4:
                        self.ip = ipaddr['addr']
                        return True

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

    def configure(self, net_settings, playbook, apex_temp_dir):
        """
        Configures undercloud VM
        :return:
        """
        # TODO(trozet): If undercloud install fails we can add a retry
        logging.info("Configuring Undercloud...")
        # run ansible
        ansible_vars = Undercloud.generate_config(net_settings)
        ansible_vars['apex_temp_dir'] = apex_temp_dir
        utils.run_ansible(ansible_vars, playbook, host=self.ip, user='stack')
        logging.info("Undercloud installed!")

    def setup_volumes(self):
        for img_file in ('overcloud-full.vmlinuz', 'overcloud-full.initrd',
                         'undercloud.qcow2'):
            src_img = os.path.join(self.image_path, img_file)
            dest_img = os.path.join(constants.LIBVIRT_VOLUME_PATH, img_file)
            if not os.path.isfile(src_img):
                raise ApexUndercloudException(
                    "Required source file does not exist:{}".format(src_img))
            if os.path.exists(dest_img):
                os.remove(dest_img)
            shutil.copyfile(src_img, dest_img)

        # TODO(trozet):check if resize needed right now size is 50gb
        # there is a lib called vminspect which has some dependencies and is
        # not yet available in pip.  Consider switching to this lib later.
        # execute ansible playbook

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
    def generate_config(ns):
        """
        Generates a dictionary of settings for configuring undercloud
        :param ns: network settings to derive undercloud settings
        :return: dictionary of settings
        """

        ns_admin = ns['networks']['admin']
        intro_range = ns['apex']['networks']['admin']['introspection_range']
        config = dict()
        config['undercloud_config'] = [
            "enable_ui false",
            "undercloud_update_packages false",
            "undercloud_debug false",
            "undercloud_hostname undercloud.{}".format(ns['dns-domain']),
            "local_ip {}/{}".format(str(ns_admin['installer_vm']['ip']),
                                    str(ns_admin['cidr']).split('/')[1]),
            "network_gateway {}".format(str(ns_admin['installer_vm']['ip'])),
            "network_cidr {}".format(str(ns_admin['cidr'])),
            "dhcp_start {}".format(str(ns_admin['dhcp_range'][0])),
            "dhcp_end {}".format(str(ns_admin['dhcp_range'][1])),
            "inspection_iprange {}".format(','.join(intro_range))
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

        # FIXME (trozet): for now hardcoding aarch64 to false
        config['aarch64'] = False

        return config
