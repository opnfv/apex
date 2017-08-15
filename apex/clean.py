##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Clean will eventually be migrated to this file

import argparse
import logging
import os
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
            connection.target = pyipmi.Target(0x20)
            connection.session.set_auth_type_user(node_info['ipmi_user'],
                                                  node_info['ipmi_pass'])
            connection.session.establish()
            connection.chassis_control_power_down()
        except Exception as e:
            logging.error("Failure while shutting down node {}".format(e))
            sys.exit(1)


def main():
    clean_parser = argparse.ArgumentParser()
    clean_parser.add_argument('-f',
                              dest='inv_file',
                              required=True,
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
    clean_nodes(args.inv_file)


if __name__ == '__main__':
    main()
