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
import re
import shutil
import subprocess

from apex.common.exceptions import ApexDeployException
from apex.network import ip_utils

NET_MAP = {
    'admin': 'br-admin',
    'tenant': 'br-tenant',
    'external': 'br-external',
    'storage': 'br-storage',
    'api': 'br-api'
}


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
                try:
                    subprocess.check_call('echo', 0, '>', ipv6_br_path)
                except subprocess.CalledProcessError:
                    logging.error("Unable to enable ipv6 on "
                                  "bridge {}".format(NET_MAP[network]))
                    raise
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


def attach_interface_to_ovs(bridge, interface, network):
    """
    Attaches jumphost interface to OVS for baremetal deployments
    :param bridge: bridge to attach to
    :param interface: interface to attach to bridge
    :param network: Apex network type for these interfaces
    :return: None
    """

    net_cfg_path = '/etc/sysconfig/network-scripts'
    if_file = os.path.join(net_cfg_path, "ifcfg-{}".format(interface))
    ovs_file = os.path.join(net_cfg_path, "ifcfg-{}".format(bridge))

    logging.info("Attaching interface: {} to bridge: {} on network {}".format(
        bridge, interface, network
    ))

    try:
        output = subprocess.check_output(['ovs-vsctl', 'list-ports', bridge],
                                         stderr=subprocess.STDOUT)
        if interface in output.decode('utf-8'):
            logging.debug("Interface already attached to bridge")
            return
    except subprocess.CalledProcessError as e:
        logging.error("Unable to dump ports for bridge: {}".format(bridge))
        logging.error("Error output: {}".format(e.output))
        raise

    if not os.path.isfile(if_file):
        logging.error("Interface ifcfg not found: {}".format(if_file))
        raise FileNotFoundError("Interface file missing: {}".format(if_file))

    ifcfg_params = {
        'IPADDR': '',
        'NETMASK': '',
        'GATEWAY': '',
        'METRIC': '',
        'DNS1': '',
        'DNS2': '',
        'PREFIX': ''
    }
    with open(if_file, 'r') as fh:
        interface_output = fh.read()

    for param in ifcfg_params.keys():
        match = re.search("{}=(.*)\n".format(param), interface_output)
        if match:
            ifcfg_params[param] = match.group(1)

    if not ifcfg_params['IPADDR']:
        logging.error("IPADDR missing in {}".format(if_file))
        raise ApexDeployException("IPADDR missing in {}".format(if_file))
    if not (ifcfg_params['NETMASK'] or ifcfg_params['PREFIX']):
        logging.error("NETMASK/PREFIX missing in {}".format(if_file))
        raise ApexDeployException("NETMASK/PREFIX missing in {}".format(
            if_file))
    if network == 'external' and not ifcfg_params['GATEWAY']:
        logging.error("GATEWAY is required to be in {} for external "
                      "network".format(if_file))
        raise ApexDeployException("GATEWAY is required to be in {} for "
                                  "external network".format(if_file))

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
    peer_dns = 'no'
    for param, value in ifcfg_params.items():
        if value:
            bridge_content += "\n{}={}".format(param, value)
            if param == 'DNS1' or param == 'DNS2':
                peer_dns = 'yes'
    bridge_content += "\n{}={}".format('PEERDNS', peer_dns)

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
