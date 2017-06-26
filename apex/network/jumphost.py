##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import logging
import subprocess

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
