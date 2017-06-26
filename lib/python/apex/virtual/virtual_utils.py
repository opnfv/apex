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
import subprocess

from apex.common import utils
from apex.virtual import configure_vm as vm_lib
from virtualbmc import vbmc


DEFAULT_RAM = 8192
DEFAULT_PM_PORT = 6230
DEFAULT_USER = 'admin'
DEFAULT_PASS = 'password'
DEFAULT_VIRT_IP = '192.168.122.1'


def generate_inventory(target_file, ha_enabled=False, num_computes=1,
                       controller_ram=DEFAULT_RAM, arch='x86_64',
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
        tmp_node['mac_address'] = vm_lib.generate_baremetal_macs(1)
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
    for name, port in node.items():
        vbmc_node = vbmc.VirtualBMC(
            username=DEFAULT_USER, password=DEFAULT_PASS, port=port,
            address=DEFAULT_VIRT_IP, domain_name=name)

        # TODO(trozet): add support for firewalld
        subprocess.call(['systemctl', 'stop', 'firewalld'])

        # iptables rule
        rule = iptc.Rule()
        rule.protocol ='udp'
        match = rule.create_match('udp')
        match.dport = port
        rule.add_match(match)
        rule.target = iptc.Target(rule, "ACCEPT")
        chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), "INPUT")
        chain.insert_rule(rule)

