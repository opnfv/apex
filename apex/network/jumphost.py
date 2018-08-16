##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import logging
import os
import shutil
import subprocess

from apex.common.exceptions import JumpHostNetworkException
from apex.common import parsers
from apex.network import ip_utils

NET_MAP = {
    'admin': 'br-admin',
    'tenant': 'br-tenant',
    'external': 'br-external',
    'storage': 'br-storage',
    'api': 'br-api'
}

NET_CFG_PATH = '/etc/sysconfig/network-scripts'


def configure_bridges(ns):
    """
    Configures IP on jumphost bridges
    :param ns: network_settings
    :return: None
    """
    bridge_networks = ['admin']
    if 'external' in ns.enabled_network_list:
        bridge_networks.append('external')
    for network in bridge_networks:
        if network == 'external':
            net_config = ns['networks'][network][0]
        else:
            net_config = ns['networks'][network]
        cidr = net_config['cidr']
        interface = ip_utils.get_interface(NET_MAP[network], cidr.version)

        if interface:
            logging.info("Bridge {} already configured with IP: {}".format(
                NET_MAP[network], interface.ip))
        else:
            logging.info("Will configure IP for {}".format(NET_MAP[network]))
            ovs_ip = net_config['overcloud_ip_range'][1]
            if cidr.version == 6:
                ipv6_br_path = "/proc/sys/net/ipv6/conf/{}/disable_" \
                               "ipv6".format(NET_MAP[network])
                with open(ipv6_br_path, 'w') as f:
                    print(0, file=f)
            try:
                ip_prefix = "{}/{}".format(ovs_ip, cidr.prefixlen)
                subprocess.check_call(['ip', 'addr', 'add', ip_prefix, 'dev',
                                      NET_MAP[network]])
                subprocess.check_call(['ip', 'link', 'set', 'up', NET_MAP[
                    network]])
                logging.info("IP configured: {} on bridge {}".format(ovs_ip,
                             NET_MAP[network]))
            except subprocess.CalledProcessError:
                logging.error("Unable to configure IP address on "
                              "bridge {}".format(NET_MAP[network]))
                raise


def generate_ifcfg_params(if_file, network):
    """
    Generates and validates ifcfg parameters required for a network
    :param if_file: ifcfg file to parse
    :param network: Apex network
    :return: dictionary of generated/validated ifcfg params
    """
    ifcfg_params = parsers.parse_ifcfg_file(if_file)
    if not ifcfg_params['IPADDR']:
        logging.error("IPADDR missing in {}".format(if_file))
        raise JumpHostNetworkException("IPADDR missing in {}".format(if_file))
    if not (ifcfg_params['NETMASK'] or ifcfg_params['PREFIX']):
        logging.error("NETMASK/PREFIX missing in {}".format(if_file))
        raise JumpHostNetworkException("NETMASK/PREFIX missing in {}".format(
            if_file))
    if network == 'external' and not ifcfg_params['GATEWAY']:
        logging.error("GATEWAY is required to be in {} for external "
                      "network".format(if_file))
        raise JumpHostNetworkException("GATEWAY is required to be in {} for "
                                       "external network".format(if_file))

    if ifcfg_params['DNS1'] or ifcfg_params['DNS2']:
        ifcfg_params['PEERDNS'] = 'yes'
    else:
        ifcfg_params['PEERDNS'] = 'no'
    return ifcfg_params


def is_ovs_bridge(bridge):
    """
    Finds an OVS bridge
    :param bridge: OVS bridge to find
    :return: boolean if OVS bridge exists
    """
    try:
        output = subprocess.check_output(['ovs-vsctl', 'show'],
                                         stderr=subprocess.STDOUT)
        if bridge not in output.decode('utf-8'):
            logging.debug("Bridge {} not found".format(bridge))
            return False
        else:
            logging.debug("Bridge {} found".format(bridge))
            return True
    except subprocess.CalledProcessError:
        logging.error("Unable to validate OVS bridge {}".format(bridge))
        raise


def dump_ovs_ports(bridge):
    """
    Returns
    :param bridge: OVS bridge to list ports
    :return: list of ports
    """
    try:
        output = subprocess.check_output(['ovs-vsctl', 'list-ports', bridge],
                                         stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError:
        logging.error("Unable to show ports for {}".format(bridge))
        raise
    return output.decode('utf-8').strip().split('\n')


def attach_interface_to_ovs(bridge, interface, network):
    """
    Attaches jumphost interface to OVS for baremetal deployments
    :param bridge: bridge to attach to
    :param interface: interface to attach to bridge
    :param network: Apex network type for these interfaces
    :return: None
    """

    if_file = os.path.join(NET_CFG_PATH, "ifcfg-{}".format(interface))
    ovs_file = os.path.join(NET_CFG_PATH, "ifcfg-{}".format(bridge))

    logging.info("Attaching interface: {} to bridge: {} on network {}".format(
        bridge, interface, network
    ))

    if not is_ovs_bridge(bridge):
        subprocess.check_call(['ovs-vsctl', 'add-br', bridge])
    elif interface in dump_ovs_ports(bridge):
        logging.debug("Interface already attached to bridge")
        return

    if not os.path.isfile(if_file):
        logging.error("Interface ifcfg not found: {}".format(if_file))
        raise FileNotFoundError("Interface file missing: {}".format(if_file))
    ifcfg_params = generate_ifcfg_params(if_file, network)
    shutil.move(if_file, "{}.orig".format(if_file))
    if_content = """DEVICE={}
DEVICETYPE=ovs
TYPE=OVSPort
PEERDNS=no
BOOTPROTO=static
NM_CONTROLLED=no
ONBOOT=yes
OVS_BRIDGE={}
PROMISC=yes""".format(interface, bridge)

    bridge_content = """DEVICE={}
DEVICETYPE=ovs
BOOTPROTO=static
ONBOOT=yes
TYPE=OVSBridge
PROMISC=yes""".format(bridge)
    for param, value in ifcfg_params.items():
        if value:
            bridge_content += "\n{}={}".format(param, value)

    logging.debug("New interface file content:\n{}".format(if_content))
    logging.debug("New bridge file content:\n{}".format(bridge_content))
    with open(if_file, 'w') as fh:
        fh.write(if_content)
    with open(ovs_file, 'w') as fh:
        fh.write(bridge_content)
    logging.info("New network ifcfg files written")
    logging.info("Restarting Linux networking")
    try:
        subprocess.check_call(['systemctl', 'restart', 'network'])
    except subprocess.CalledProcessError:
        logging.error("Failed to restart Linux networking")
        raise


def detach_interface_from_ovs(network):
    """
    Detach interface from OVS for baremetal deployments
    :param network: Apex network to detach single interface from
    :return: None
    """

    bridge = NET_MAP[network]
    logging.debug("Detaching interfaces from bridge on network: {}".format(
        network))
    # ensure bridge exists
    if not is_ovs_bridge(bridge):
        return

    # check if real port is on bridge
    for interface in dump_ovs_ports(bridge):
        if interface and not interface.startswith('vnet'):
            logging.debug("Interface found: {}".format(interface))
            real_interface = interface
            break
    else:
        logging.info("No jumphost interface exists on bridge {}".format(
            bridge))
        return

    # check if original backup ifcfg file exists or create
    orig_ifcfg_file = os.path.join(NET_CFG_PATH,
                                   "ifcfg-{}.orig".format(real_interface))
    ifcfg_file = orig_ifcfg_file[:-len('.orig')]
    bridge_ifcfg_file = os.path.join(NET_CFG_PATH,
                                     "ifcfg-{}".format(bridge))
    if os.path.isfile(orig_ifcfg_file):
        logging.debug("Original interface file found: "
                      "{}".format(orig_ifcfg_file))
    else:
        logging.info("No original ifcfg file found...will attempt to use "
                     "bridge ifcfg file and re-create")
        if os.path.isfile(bridge_ifcfg_file):
            ifcfg_params = generate_ifcfg_params(bridge_ifcfg_file, network)
            if_content = """DEVICE={}
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
NM_CONTROLLED=no""".format(real_interface)
            for param, value in ifcfg_params.items():
                if value:
                    if_content += "\n{}={}".format(param, value)
            logging.debug("Interface file content:\n{}".format(if_content))
            # write original backup
            with open(orig_ifcfg_file, 'w') as fh:
                fh.write(if_content)
            logging.debug("Original interface file created: "
                          "{}".format(orig_ifcfg_file))
        else:
            logging.error("Unable to find original interface config file: {} "
                          "or bridge config file:{}".format(orig_ifcfg_file,
                                                            bridge_ifcfg_file))
            raise FileNotFoundError("Unable to locate bridge or original "
                                    "interface ifcfg file")

    # move original file back and rewrite bridge ifcfg
    shutil.move(orig_ifcfg_file, ifcfg_file)
    bridge_content = """DEVICE={}
DEVICETYPE=ovs
BOOTPROTO=static
ONBOOT=yes
TYPE=OVSBridge
PROMISC=yes""".format(bridge)
    with open(bridge_ifcfg_file, 'w') as fh:
        fh.write(bridge_content)
    # restart linux networking
    logging.info("Restarting Linux networking")
    try:
        subprocess.check_call(['systemctl', 'restart', 'network'])
    except subprocess.CalledProcessError:
        logging.error("Failed to restart Linux networking")
        raise


def remove_ovs_bridge(network):
    """
    Unconfigure and remove an OVS bridge
    :param network: Apex network to remove OVS bridge for
    :return:
    """
    bridge = NET_MAP[network]
    if is_ovs_bridge(bridge):
        logging.info("Removing bridge: {}".format(bridge))
        try:
            subprocess.check_call(['ovs-vsctl', 'del-br', bridge])
        except subprocess.CalledProcessError:
            logging.error('Unable to destroy OVS bridge')
            raise

        logging.debug('Bridge destroyed')
        bridge_ifcfg_file = os.path.join(NET_CFG_PATH,
                                         "ifcfg-{}".format(bridge))
        if os.path.isfile(bridge_ifcfg_file):
            os.remove(bridge_ifcfg_file)
            logging.debug("Bridge ifcfg file removed: {}".format(
                bridge_ifcfg_file))
        else:
            logging.debug('Bridge ifcfg file not found')
