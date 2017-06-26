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

from apex.common.exceptions import ApexDeployException

"""Parser functions for overcloud/openstack output"""


def parse_nova_output(in_file):
    """
    Parses nova list output into a dictionary format for node name and ip
    :param in_file:
    :return: list of dictionary format for [{"node name": "node ip"},]
    """
    if not os.path.isfile(in_file):
        raise FileNotFoundError(in_file)
    node_list = list()
    with open(in_file, 'r') as fh:
        lines = fh.readlines()

    # default positions for fields in nova list output
    fields = {'name': 1, 'networks': 5}

    for line in lines:
        if '|' not in line:
            continue
        else:
            output = [x.strip().lower() for x in line.split('|')]
        if 'ID' in line:
            # we know we are in header row, update fields
            for idx, element in enumerate(output):
                for field in 'name', 'networks':
                    if element == field:
                        fields[field] = idx
        else:
            ip_match = re.search('([0-9]+\.){3}[0-9]+', output[fields[
                'networks']])
            if ip_match is None:
                logging.error("Unable to find IP in nova output line "
                              "{}".format(line))
                raise ApexDeployException("Unable to parse IP from field")
            else:
                node_list.append({[output[fields['name']]]: ip_match.group(0)})

    return node_list
