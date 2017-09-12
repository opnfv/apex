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
    if not ns:
        raise NetworkDataException('Invalid network settings given')

    nets = ns['networks']

    for net in nets:
        if net == ADMIN_NETWORK:
            # we dont need to add ctlplane network to network data
            continue
        net_range = net['overcloud_ip_range']
        # TODO(trozet): add ipv6 support
        tmp_net = {'name': net,
                   'name_lower': net.lower(),
                   'ip_subnet': str(net['cidr']),
                   'allocation_pools': [{'start': str(net_range[0]),
                                         'end': str(net_range[1])}],
                   'gateway_ip': str(net['gateway']),
                   'vip': net != TENANT_NETWORK,
                   'enabled': net in ns.enabled_network_list}
        network_data.append(copy.deepcopy(tmp_net))

    if target:
        logging.debug("Writing network data to {}".format(target))
        utils.dump_yaml(network_data, target)
    logging.debug("Network data parsed as:\n "
                  "{}".format(pprint.pformat(network_data)))
    return network_data
