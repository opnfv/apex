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

    for net in nets.keys():
        if net == ADMIN_NETWORK:
            # we dont need to add ctlplane network to network data
            continue
        elif net == EXTERNAL_NETWORK:
            network = nets[net][0]
        else:
            network = nets[net]
        # TODO(trozet): add ipv6 support
        tmp_net = {'name': net,
                   'name_lower': net.lower(),
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
        if 'cidr' in network:
            tmp_net['ip_subnet'] = str(network['cidr'])
        elif tmp_net['enabled']:
            logging.error("cidr is missing and must be provided in network "
                          "settings when network is enabled for network "
                          "{}".format(net))
            raise NetworkDataException("cidr is null for network {}".format(
                net))

        network_data.append(copy.deepcopy(tmp_net))

    if target:
        logging.debug("Writing network data to {}".format(target))
        utils.dump_yaml(network_data, target)
    logging.debug("Network data parsed as:\n "
                  "{}".format(pprint.pformat(network_data)))
    return network_data
