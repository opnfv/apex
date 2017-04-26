##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Clean will eventually be migrated to this file

import logging
import pyipmi
import pyipmi.interfaces
import sys

from .common import utils


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
            if 'ipmi_target_addr' in node_info:
                connection.target = pyipmi.Target(node['ipmi_target_addr'])
            else:
                connection.target = pyipmi.Target(0x20)
            connection.session.set_auth_type_user(node_info['ipmi_user'],
                                                  node_info['ipmi_pass'])
            connection.session.establish()
            connection.chassis_control_power_down()
        except Exception as e:
            logging.error("Failure while shutting down node {}".format(e))
            sys.exit(1)
