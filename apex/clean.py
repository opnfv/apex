##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import fileinput
import libvirt
import logging
import os
import pyipmi
import pyipmi.interfaces
import sys

from apex.common import (
    constants,
    utils)
from apex.network import jumphost
from apex.common.exceptions import ApexCleanException
from virtualbmc import manager as vbmc_lib


def clean_nodes(inventory):
    inv_dict = utils.parse_yaml(inventory)
    if inv_dict is None or 'nodes' not in inv_dict:
        logging.error("Inventory file is empty or missing nodes definition")
        sys.exit(1)
    for node, node_info in inv_dict['nodes'].items():
        logging.info("Cleaning node: {}".format(node))
        try:
            interface = pyipmi.interfaces.create_interface(
                'ipmitool', interface_type='lanplus')
            connection = pyipmi.create_connection(interface)
            connection.session.set_session_type_rmcp(node_info['ipmi_ip'])
            connection.target = pyipmi.Target(0x20)
            connection.session.set_auth_type_user(node_info['ipmi_user'],
                                                  node_info['ipmi_pass'])
            connection.session.establish()
            connection.chassis_control_power_down()
        except Exception as e:
            logging.error("Failure while shutting down node {}".format(e))
            sys.exit(1)


def clean_vbmcs():
    vbmc_manager = vbmc_lib.VirtualBMCManager()
    _, vbmcs = vbmc_manager.list()
    for vbmc in vbmcs:
        logging.info("Deleting vbmc: {}".format(vbmc['domain_name']))
        vbmc_manager.delete(vbmc['domain_name'])


def clean_vms():
    logging.info('Destroying all Apex VMs')
    conn = libvirt.open('qemu:///system')
    if not conn:
        raise ApexCleanException('Unable to open libvirt connection')
    pool = conn.storagePoolLookupByName('default')
    domains = conn.listAllDomains()

    for domain in domains:
        vm = domain.name()
        if vm != 'undercloud' and not vm.startswith('baremetal'):
            continue
        logging.info("Cleaning domain: {}".format(vm))
        if domain.isActive():
            logging.debug('Destroying domain')
            domain.destroy()
        domain.undefineFlags(libvirt.VIR_DOMAIN_UNDEFINE_NVRAM)
        # delete storage volume
        try:
            stgvol = pool.storageVolLookupByName("{}.qcow2".format(vm))
        except libvirt.libvirtError:
            logging.warning("Skipping volume cleanup as volume not found for "
                            "vm: {}".format(vm))
            stgvol = None
        if stgvol:
            logging.info('Deleting storage volume')
            stgvol.wipe(0)
            stgvol.delete(0)
    pool.refresh()


def clean_ssh_keys(key_file='/root/.ssh/authorized_keys'):
    logging.info('Removing any stack pub keys from root authorized keys')
    if not os.path.isfile(key_file):
        logging.warning("Key file does not exist: ".format(key_file))
        return
    for line in fileinput.input(key_file, inplace=True):
        line = line.strip('\n')
        if 'stack@undercloud' not in line:
            print(line)


def clean_networks():
    logging.debug('Cleaning all network config')
    for network in constants.OPNFV_NETWORK_TYPES:
        logging.info("Cleaning Jump Host Network config for network "
                     "{}".format(network))
        jumphost.detach_interface_from_ovs(network)
        jumphost.remove_ovs_bridge(network)

    conn = libvirt.open('qemu:///system')
    if not conn:
        raise ApexCleanException('Unable to open libvirt connection')
    logging.debug('Destroying all virsh networks')
    for network in conn.listNetworks():
        if network in constants.OPNFV_NETWORK_TYPES:
            virsh_net = conn.networkLookupByName(network)
            logging.debug("Destroying virsh network: {}".format(network))
            if virsh_net.isActive():
                virsh_net.destroy()
            try:
                virsh_net.undefine()
            except libvirt.libvirtError as e:
                if 'Network not found' in e.get_error_message():
                    logging.debug('Network already undefined')
                else:
                    raise


def main():
    clean_parser = argparse.ArgumentParser()
    clean_parser.add_argument('-i',
                              dest='inv_file',
                              required=False,
                              default=None,
                              help='File which contains inventory')
    args = clean_parser.parse_args(sys.argv[1:])
    os.makedirs(os.path.dirname('./apex_clean.log'), exist_ok=True)
    formatter = '%(asctime)s %(levelname)s: %(message)s'
    logging.basicConfig(filename='./apex_clean.log',
                        format=formatter,
                        datefmt='%m/%d/%Y %I:%M:%S %p',
                        level=logging.DEBUG)
    console = logging.StreamHandler()
    console.setLevel(logging.DEBUG)
    console.setFormatter(logging.Formatter(formatter))
    logging.getLogger('').addHandler(console)
    if args.inv_file:
        if not os.path.isfile(args.inv_file):
            logging.error("Inventory file not found: {}".format(args.inv_file))
            raise FileNotFoundError("Inventory file does not exist")
        else:
            logging.info("Shutting down baremetal nodes")
            clean_nodes(args.inv_file)
    # Delete all VMs
    clean_vms()
    # Delete vbmc
    clean_vbmcs()
    # Clean network config
    clean_networks()

    # clean pub keys from root's auth keys
    clean_ssh_keys()

    logging.info('Apex clean complete!')


if __name__ == '__main__':
    main()
