##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import copy
import logging
import pprint

from apex.common import utils
from apex.common.constants import (
    ADMIN_NETWORK,
    TENANT_NETWORK,
    STORAGE_NETWORK,
    EXTERNAL_NETWORK,
    API_NETWORK
)
from apex import NetworkSettings


class NetworkDataException(Exception):
    pass


def create_network_data(ns, target=None):
    """
    Creates network data file for deployments
    :param ns: Network Settings
    :param target: Target file to write
    :return: list of networks and properties
    """
    network_data = list()
    if not isinstance(ns, NetworkSettings):
        raise NetworkDataException('Invalid network settings given')

    nets = ns['networks']

    # TODO(trozet) change this all to be dynamic after TripleO bug
    # https://bugs.launchpad.net/tripleo/+bug/1720849 is fixed

    for net in nets.keys():
        if net == ADMIN_NETWORK:
            # we dont need to add ctlplane network to network data
            continue
        elif net == EXTERNAL_NETWORK:
            network = nets[net][0]
            net_name = net.title()
            net_lower = net.lower()
        elif net == API_NETWORK:
            network = nets[net]
            net_name = 'InternalApi'
            net_lower = 'internal_api'
        else:
            network = nets[net]
            net_name = net.title()
            net_lower = net.lower()
        # TODO(trozet): add ipv6 support
        tmp_net = {'name': net_name,
                   'name_lower': net_lower,
                   'vip': net != TENANT_NETWORK,
                   'enabled': net in ns.enabled_network_list}
        if 'gateway' in network:
            tmp_net['gateway_ip'] = str(network['gateway'])
        if 'overcloud_ip_range' in network:
            net_range = network['overcloud_ip_range']
            tmp_net['allocation_pools'] = [{'start': str(net_range[0]),
                                           'end': str(net_range[1])}]
        elif tmp_net['enabled']:
            logging.error("overcloud ip range is missing and must be provided "
                          "in network settings when network is enabled for "
                          "network {}".format(net))
            raise NetworkDataException("overcloud_ip_range missing from "
                                       "network: {}".format(net))
        if 'cidr' in network:
            tmp_net['ip_subnet'] = str(network['cidr'])
        elif tmp_net['enabled']:
            logging.error("cidr is missing and must be provided in network "
                          "settings when network is enabled for network "
                          "{}".format(net))
            raise NetworkDataException("cidr is null for network {}".format(
                net))
        tmp_net['mtu'] = network.get('mtu', 1500)
        network_data.append(copy.deepcopy(tmp_net))

    # have to do this due to the aforementioned bug
    storage_mgmt_net = {
        'name': 'StorageMgmt',
        'enabled': False,
        'name_lower': 'storage_mgmt',
        'ip_subnet': '172.16.3.0/24',
        'allocation_pools': [{'start': '172.16.3.4', 'end': '172.16.3.250'}],
        'vip': True,
    }
    network_data.append(storage_mgmt_net)
    if target:
        logging.debug("Writing network data to {}".format(target))
        utils.dump_yaml(network_data, target)
    logging.debug("Network data parsed as:\n "
                  "{}".format(pprint.pformat(network_data)))
    return network_data
