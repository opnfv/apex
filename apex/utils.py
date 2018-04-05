##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# TODO(trozet) migrate rest of utils.sh here

import argparse
import datetime
import logging
import os
import sys
import tempfile

from apex.common import constants
from apex.common import parsers
from apex.undercloud import undercloud as uc_lib
from apex.common import utils

VALID_UTILS = ['fetch_logs']
START_TIME = datetime.datetime.now().strftime("%Y-%m-%d-%H:%M")
APEX_TEMP_DIR = tempfile.mkdtemp(prefix="apex-logs-{}-".format(START_TIME))


def fetch_logs(args):
    uc_ip = uc_lib.Undercloud.get_ip()
    if not uc_ip:
        raise Exception('No Undercloud IP found')
    logging.info("Undercloud IP is: {}".format(uc_ip))
    fetch_vars = dict()
    fetch_vars['stackrc'] = 'source /home/stack/stackrc'
    fetch_vars['apex_temp_dir'] = APEX_TEMP_DIR
    fetch_playbook = os.path.join(args.lib_dir, constants.ANSIBLE_PATH,
                                  'fetch_overcloud_nodes.yml')
    try:
        utils.run_ansible(fetch_vars, fetch_playbook, host=uc_ip,
                          user='stack', tmp_dir=APEX_TEMP_DIR)
        logging.info("Retrieved overcloud nodes info")
    except Exception:
        logging.error("Failed to retrieve overcloud nodes.  Please check log")
        raise
    nova_output = os.path.join(APEX_TEMP_DIR, 'nova_output')
    fetch_vars['overcloud_nodes'] = parsers.parse_nova_output(nova_output)
    fetch_vars['SSH_OPTIONS'] = '-o StrictHostKeyChecking=no -o ' \
                                'GlobalKnownHostsFile=/dev/null -o ' \
                                'UserKnownHostsFile=/dev/null -o ' \
                                'LogLevel=error'
    fetch_playbook = os.path.join(args.lib_dir, constants.ANSIBLE_PATH,
                                  'fetch_overcloud_logs.yml')
    # Run per overcloud node
    for node, ip in fetch_vars['overcloud_nodes'].items():
        logging.info("Executing fetch logs overcloud playbook on "
                     "node {}".format(node))
        try:
            utils.run_ansible(fetch_vars, fetch_playbook, host=ip,
                              user='heat-admin', tmp_dir=APEX_TEMP_DIR)
            logging.info("Logs retrieved for node {}".format(node))
        except Exception:
            logging.error("Log retrieval failed "
                          "for node {}. Please check log".format(node))
            raise
    logging.info("Log retrieval complete and stored in {}".format(
        APEX_TEMP_DIR))


def execute_actions(args):
    for action in VALID_UTILS:
        if hasattr(args, action) and getattr(args, action):
            util_module = __import__('utils')
            func = getattr(util_module, action)
            logging.info("Executing action: {}".format(action))
            func(args)


def main():
    util_parser = argparse.ArgumentParser()
    util_parser.add_argument('-f', '--fetch-logs',
                             dest='fetch_logs',
                             required=False,
                             default=False,
                             action='store_true',
                             help='Fetch all overcloud logs')
    util_parser.add_argument('--lib-dir',
                             default='/usr/share/opnfv-apex',
                             help='Directory path for apex ansible '
                                  'and third party libs')
    args = util_parser.parse_args(sys.argv[1:])
    os.makedirs(os.path.dirname('./apex_util.log'), exist_ok=True)
    formatter = '%(asctime)s %(levelname)s: %(message)s'
    logging.basicConfig(filename='./apex_util.log',
                        format=formatter,
                        datefmt='%m/%d/%Y %I:%M:%S %p',
                        level=logging.DEBUG)
    console = logging.StreamHandler()
    console.setLevel(logging.DEBUG)
    console.setFormatter(logging.Formatter(formatter))
    logging.getLogger('').addHandler(console)

    execute_actions(args)


if __name__ == '__main__':
    main()
