##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import copy
import iptc
import logging
import os
import platform
import pprint
import subprocess

from apex.common import utils
from apex.virtual import configure_vm as vm_lib
from virtualbmc import manager as vbmc_lib

DEFAULT_RAM = 8192
DEFAULT_PM_PORT = 6230
DEFAULT_USER = 'admin'
DEFAULT_PASS = 'password'
DEFAULT_VIRT_IP = '192.168.122.1'


def generate_inventory(target_file, ha_enabled=False, num_computes=1,
                       controller_ram=DEFAULT_RAM, arch=platform.machine(),
                       compute_ram=DEFAULT_RAM, vcpus=4):
    """
    Generates inventory file for virtual deployments
    :param target_file:
    :param ha_enabled:
    :param num_computes:
    :param controller_ram:
    :param arch:
    :param compute_ram:
    :param vcpus:
    :return:
    """

    node = {'mac_address': '',
            'ipmi_ip': DEFAULT_VIRT_IP,
            'ipmi_user': DEFAULT_USER,
            'ipmi_pass': DEFAULT_PASS,
            'pm_type': 'pxe_ipmitool',
            'pm_port': '',
            'cpu': vcpus,
            'memory': DEFAULT_RAM,
            'disk': 41,
            'arch': arch,
            'capabilities': ''
            }

    inv_output = {'nodes': {}}
    if ha_enabled:
        num_ctrlrs = 3
    else:
        num_ctrlrs = 1

    for idx in range(num_ctrlrs + num_computes):
        tmp_node = copy.deepcopy(node)
        tmp_node['mac_address'] = vm_lib.generate_baremetal_macs(1)[0]
        tmp_node['pm_port'] = DEFAULT_PM_PORT + idx
        if idx < num_ctrlrs:
            tmp_node['capabilities'] = 'profile:control'
            tmp_node['memory'] = controller_ram
        else:
            tmp_node['capabilities'] = 'profile:compute'
            tmp_node['memory'] = compute_ram
        inv_output['nodes']['node{}'.format(idx)] = copy.deepcopy(tmp_node)

    utils.dump_yaml(inv_output, target_file)

    logging.info('Virtual environment file created: {}'.format(target_file))


def host_setup(node):
    """
    Handles configuring vmbc and firewalld/iptables
    :param node: dictionary of domain names and ports for ipmi
    :return:
    """
    vbmc_manager = vbmc_lib.VirtualBMCManager()
    for name, port in node.items():
        vbmc_manager.add(username=DEFAULT_USER, password=DEFAULT_PASS,
                         port=port, address=DEFAULT_VIRT_IP, domain_name=name,
                         libvirt_uri='qemu:///system',
                         libvirt_sasl_password=False,
                         libvirt_sasl_username=False)

        # TODO(trozet): add support for firewalld
        try:
            subprocess.check_call(['systemctl', 'stop', 'firewalld'])
            subprocess.check_call(['systemctl', 'restart', 'libvirtd'])
        except subprocess.CalledProcessError:
            logging.warning('Failed to stop firewalld and restart libvirtd')
        # iptables rule
        rule = iptc.Rule()
        rule.protocol = 'udp'
        match = rule.create_match('udp')
        match.dport = str(port)
        rule.add_match(match)
        rule.target = iptc.Target(rule, "ACCEPT")
        chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), "INPUT")
        chain.insert_rule(rule)
        try:
            subprocess.check_call(['vbmc', 'start', name])
            logging.debug("Started vbmc for domain {}".format(name))
        except subprocess.CalledProcessError:
            logging.error("Failed to start vbmc for {}".format(name))
            raise
    logging.debug('vmbcs setup: {}'.format(vbmc_manager.list()))


def virt_customize(ops, target):
    """
    Helper function to virt customize disks
    :param ops: list of of operations and arguments
    :param target: target disk to modify
    :return: None
    """
    logging.info("Virt customizing target disk: {}".format(target))
    virt_cmd = ['virt-customize']
    for op in ops:
        for op_cmd, op_arg in op.items():
            virt_cmd.append(op_cmd)
            virt_cmd.append(op_arg)
    virt_cmd.append('-a')
    virt_cmd.append(target)
    if not os.path.isfile(target):
        raise FileNotFoundError
    my_env = os.environ.copy()
    my_env['LIBGUESTFS_BACKEND'] = 'direct'
    logging.debug("Virt-customizing with: \n{}".format(virt_cmd))
    try:
        logging.debug(subprocess.check_output(virt_cmd, env=my_env,
                                              stderr=subprocess.STDOUT))
    except subprocess.CalledProcessError as e:
        logging.error("Error executing virt-customize: {}".format(
                      pprint.pformat(e.output)))
        raise
