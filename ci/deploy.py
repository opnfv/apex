##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import logging
import os
import sys
import tempfile

from apex import DeploySettings
from apex import Inventory
from apex import NetworkEnvironment
from apex import NetworkSettings
from apex.common import utils
from apex.quickstart import deploy_quickstart

DEPLOY_LOG_FILE = './apex_deploy.log'
OPNFV_ENV_FILE = 'opnfv-environment.yaml'
DEFAULT_PING_SITE = '8.8.8.8'
DEFAULT_DNS_SITE = 'www.google.com'
DEFAULT_VIRTUAL_CPUS = 4
DEFAULT_VIRTUAL_COMPUTES = 1
DEFAULT_VIRTUAL_RAM = 8
DEFAULT_VIRTUAL_COMPUTE_RAM = 8
DEFAULT_DEPLOY_DIR ='/var/opt/opnfv'
NET_ENV_FILE = 'network-environment.yaml'
INVENTORY_FILE = 'instackenv.json'
APEX_TEMP_DIR = tempfile.mkdtemp()

QUICKSTART_REPO = 'https://github.com/openstack/tripleo-quickstart'
QUICKSTART_REF = 'master'
QUICKSTART_PLAYBOOK = 'apex-overcloud.yml'
QUICKSTART_VIRTHOST = 'localhost'

class ApexDeployException(Exception):
    pass

def apex_deploy_quickstart(args, deploy_settings_file, network_settings_file,
                      inventory_file=None):
    deploy_quickstart(args, deploy_settings_file, network_settings_file,
                            inventory_file)

def deploy_bash():
    pass

def validate_cross_settings(deploy_settings, net_settings, inventory):
    pass

def create_deploy_parser():
    deploy_parser = argparse.ArgumentParser()
    deploy_parser.add_argument('--debug', action='store_true', default=False,
                               help="Turn on debug messages")
    deploy_parser.add_argument('-l', '--log-file',
                               default=DEPLOY_LOG_FILE,
                               dest='log_file', help="Log file to log to")
    deploy_parser.add_argument('-d', '--deploy-settings',
                               dest='deploy_settings_file',
                               required=True,
                               help='File which contains Apex deploy settings')
    deploy_parser.add_argument('-n', '--network-settings',
                               dest='network_settings_file',
                               required=True,
                               help='File which contains Apex network '
                                    'settings')
    deploy_parser.add_argument('-i', '--inventory-file',
                               dest='inventory_file',
                               default=None,
                               help='Inventory file which contains POD '
                                    'definition')
    deploy_parser.add_argument('-e', '--environment-file',
                               dest='env_file',
                               default=OPNFV_ENV_FILE,
                               help='Provide alternate base env file')
    deploy_parser.add_argument('-p', '--ping-site',
                               dest='ping_site',
                               default=DEFAULT_PING_SITE,
                               help='Provide alternate IP to verify internet '
                                    'connectivity')
    deploy_parser.add_argument('--dns-lookup-site',
                               dest='dns_site',
                               default=DEFAULT_DNS_SITE,
                               help='Provide alternate website to verify DNS '
                                    'resolution')
    deploy_parser.add_argument('-v', '--virtual', action='store_true',
                               default=False,
                               dest='virtual',
                               help='Enable virtual deployment')
    deploy_parser.add_argument('--interactive', action='store_true',
                               default=False,
                               help='Enable interactive deployment mode which '
                                    'requires user to confirm steps of '
                                    'deployment')
    deploy_parser.add_argument('--virtual-computes',
                               dest='virt_compute_nodes',
                               default=DEFAULT_VIRTUAL_COMPUTES,
                               help='Number of Virtual Compute nodes to create'
                                    ' and use during deployment (defaults to 1'
                                    ' for noha and 2 for ha)')
    deploy_parser.add_argument('--virtual-cpus',
                               dest='virt_cpus',
                               default=DEFAULT_VIRTUAL_CPUS,
                               help='Number of CPUs to use per Overcloud VM in'
                                    ' a virtual deployment (defaults to 4)')
    deploy_parser.add_argument('--virtual-default-ram',
                               dest='virt_default_ram',
                               default=DEFAULT_VIRTUAL_RAM,
                               help='Amount of default RAM to use per '
                                    'Overcloud VM in GB (defaults to 8).')
    deploy_parser.add_argument('--virtual-compute-ram',
                               dest='virt_compute_ram',
                               default=DEFAULT_VIRTUAL_COMPUTE_RAM,
                               help='Amount of RAM to use per Overcloud '
                                    'Compute VM in GB (defaults to 8). '
                                    'Overrides --virtual-default-ram arg for '
                                    'computes')
    deploy_parser.add_argument('--deploy-dir',
                               default=DEFAULT_DEPLOY_DIR,
                               help='Directory to deploy from which contains '
                                    'base config files for deployment')

    deploy_parser.add_argument('--quickstart', action='store_true',
                               default=False,
                               help='Use tripleo-quickstart to deploy')

    deploy_parser.add_argument('--quickstart-ref',
                               default=QUICKSTART_REF,
                               help='Git ref to use for tripleo-quickstart')
    deploy_parser.add_argument('--quickstart-repo',
                               default=QUICKSTART_REPO,
                               help='Git repo to use for tripleo-quickstart')
    deploy_parser.add_argument('--quickstart-playbook',
                               default=QUICKSTART_PLAYBOOK,
                               help='Ansible playbook to use for tripleo-quickstart')
    deploy_parser.add_argument('--quickstart-virthost',
                               default=QUICKSTART_VIRTHOST,
                               help='Host on which to deploy undercloud')


    return deploy_parser


def validate_deploy_args(args):
    """
    Validates arguments for deploy
    :param args:
    :return: None
    """

    logging.debug('Validating arguments for deployment')
    if args.virtual and args.inventory_file is not None:
        logging.error("Virtual enabled but inventory file also given")
        raise ApexDeployException('You should not specify an inventory file '
                                  'with virtual deployments')
    elif args.virtual:
        args.inventory_file = "{}/inventory-virt.yaml".format(
            APEX_TEMP_DIR)
    elif os.path.isfile(args.inventory_file) is False:
        logging.error("Specified inventory file does not exist: {}".format(
            args.inventory_file))
        raise ApexDeployException('Specified inventory file does not exist')

    for settings_file in (args.deploy_settings_file,
                          args.network_settings_file):
        if os.path.isfile(settings_file) is False:
            logging.error("Specified settings file does not "
                          "exist: {}".format(settings_file))
            raise ApexDeployException('Specified settings file does not '
                                      'exist: {}'.format(settings_file))


if __name__ == '__main__':
    parser = create_deploy_parser()
    args = parser.parse_args(sys.argv[1:])
    if args.debug:
        log_level = logging.DEBUG
    else:
        log_level = logging.INFO
    os.makedirs(os.path.dirname(args.log_file), exist_ok=True)
    formatter = '%(asctime)s %(levelname)s: %(message)s'
    logging.basicConfig(filename=args.log_file,
                        format=formatter,
                        datefmt='%m/%d/%Y %I:%M:%S %p',
                        level=log_level)
    console = logging.StreamHandler()
    console.setLevel(log_level)
    console.setFormatter(logging.Formatter(formatter))
    logging.getLogger('').addHandler(console)
    validate_deploy_args(args)
    # Parse all settings
    deploy_settings = DeploySettings(args.deploy_settings_file)
    net_settings = NetworkSettings(args.network_settings_file)
    net_env_file = os.path.join(args.deploy_dir, NET_ENV_FILE)
    net_env = NetworkEnvironment(net_settings, net_env_file)
    net_env_target = os.path.join(APEX_TEMP_DIR, NET_ENV_FILE)
    utils.dump_yaml(dict(net_env), net_env_target)

    inventory_file = None
    inventory = None

    # Quickstart will load the inventory and template it directly
    if (not args.quickstart):
        inventory = Inventory(args.inventory_file, deploy_settings[
            'ha_enabled'], args.virtual)
        inventory_file = os.path.join(APEX_TEMP_DIR, INVENTORY_FILE)
        with open(inventory_file, 'w') as inventory_fh:
            inventory.dump_instackenv_json(fh)

    # TODO(trozet) logging of settings
    validate_cross_settings(deploy_settings, net_settings, inventory)

    if args.quickstart:
        deploy_settings_file = "{}/apex_deploy_settings.yaml".format(APEX_TEMP_DIR)
        deploy_settings.dump_yaml(deploy_settings_file)

        # (michchap) network settings currently have python objects embedded, so
        # don't dump nicely. Using raw net settings until this is fixed
        #net_settings.dump_yaml("{}/apex_net_settings.yaml".format(APEX_TEMP_DIR))

        apex_deploy_quickstart(args, deploy_settings_file, args.network_settings_file,
                          inventory_file)
    else:
        # Dump all settings out to temp bash files to be sourced
        deploy_settings.dump_bash("{}/deploy_settings.sh".format(APEX_TEMP_DIR))
        net_settings.dump_bash("{}/network_settings.sh".format(APEX_TEMP_DIR))
        deploy_bash()
