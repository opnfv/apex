#!/usr/bin/env python

##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import json
import logging
import os
import pprint
import sys
import tempfile

import apex.virtual.configure_vm as vm_lib
import apex.virtual.virtual_utils as virt_utils
from apex import DeploySettings
from apex import Inventory
from apex import NetworkEnvironment
from apex import NetworkSettings
from apex.common import utils

DEPLOY_LOG_FILE = './apex_deploy.log'
OPNFV_ENV_FILE = 'opnfv-environment.yaml'
DEFAULT_PING_SITE = '8.8.8.8'
DEFAULT_DNS_SITE = 'www.google.com'
DEFAULT_VIRTUAL_CPUS = 4
DEFAULT_VIRTUAL_COMPUTES = 1
DEFAULT_VIRTUAL_RAM = 8
DEFAULT_DEPLOY_DIR = '/var/opt/opnfv'
NET_ENV_FILE = 'network-environment.yaml'
INVENTORY_FILE = 'instackenv.json'
LIBVIRT_VOLUME_PATH = '/var/lib/libvirt/images'
APEX_TEMP_DIR = tempfile.mkdtemp()
ANSIBLE_PATH = 'lib/ansible/playbooks'


class ApexDeployException(Exception):
    pass


def deploy_quickstart(args, deploy_settings_file, network_settings_file,
                      inventory_file=None):
    pass


def deploy_bash():
    pass


def validate_cross_settings(deploy_settings, net_settings, inventory):
    """
    Used to validate compatibility across settings file.
    :param deploy_settings: parsed settings for deployment
    :param net_settings: parsed settings for network
    :param inventory: parsed inventory file
    :return: None
    """

    if deploy_settings['deploy_options']['dataplane'] != 'ovs' and 'tenant' \
            not in net_settings.enabled_network_list:
        raise ApexDeployException("Setting a DPDK based dataplane requires"
                                  "a dedicated NIC for tenant network")

    #TODO(trozet): add more checks here like RAM for ODL, etc


def build_vms(inventory, network_settings):
    """
    Creates VMs and configures vbmc and host
    :param inventory:
    :param network_settings:
    :return:
    """

    for idx, node in enumerate(inventory['nodes']):
        name = 'baremetal{}'.format(idx)
        volume = name + ".qcow2"
        volume_path = os.path.join(LIBVIRT_VOLUME_PATH, volume)
        # TODO(trozet): add back aarch64
        # TODO(trozet): add error checking
        vm_lib.create_vm(
            name, volume_path,
            baremetal_interfaces=network_settings.enabled_network_list,
            memory=node['memory'], cpus=node['cpu'],
            macs=list(node['mac_address']))
        virt_utils.host_setup({name: node['pm_port']})


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
                               default=None,
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
        args.inventory_file = os.path.join(APEX_TEMP_DIR,
                                           'inventory-virt.yaml')
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
    logging.info("Deploy settings are:\n {}".format(pprint.pformat(
                 deploy_settings)))
    net_settings = NetworkSettings(args.network_settings_file)
    logging.info("Network settings are:\n {}".format(pprint.pformat(
                 net_settings)))
    net_env_file = os.path.join(args.deploy_dir, NET_ENV_FILE)
    net_env = NetworkEnvironment(net_settings, net_env_file)
    net_env_target = os.path.join(APEX_TEMP_DIR, NET_ENV_FILE)
    utils.dump_yaml(dict(net_env), net_env_target)
    ha_enabled = deploy_settings['global_params']['ha_enabled']
    if args.virtual:
        if args.virt_compute_ram is None:
            compute_ram = args.virt_default_ram
        else:
            compute_ram = args.virt_compute_ram
        if deploy_settings['deploy_options']['sdn_controller'] == \
                'opendaylight' and args.virt_default_ram < 12288:
            control_ram = 12288
            logging.warning('RAM per controller is too low.  OpenDaylight '
                            'requires at least 12GB per controller.')
            logging.info('Increasing RAM per controller to 12GB')
        elif args.virt_default_ram < 10240:
            control_ram = 10240
            logging.warning('RAM per controller is too low.  nosdn '
                            'requires at least 10GB per controller.')
            logging.info('Increasing RAM per controller to 10GB')
        else:
            control_ram = args.virt_default_ram
        virt_utils.generate_inventory(args.inventory_file, ha_enabled,
                                      num_computes=args.virt_compute_nodes,
                                      controller_ram=control_ram,
                                      compute_ram=compute_ram,
                                      vcpus=args.virt_cpus
                                      )
    inventory = Inventory(args.inventory_file, ha_enabled, args.virtual)

    validate_cross_settings(deploy_settings, net_settings, inventory)

    if args.quickstart:
        deploy_settings_file = os.path.join(APEX_TEMP_DIR,
                                            'apex_deploy_settings.yaml')
        deploy_settings.dump_yaml(deploy_settings_file)
        logging.info("File created: {}".format(deploy_settings_file))
        network_settings_file = os.path.join(APEX_TEMP_DIR,
                                             'apex_network_settings.yaml')

        net_settings.dump_yaml(network_settings_file)
        logging.info("File created: {}".format(network_settings_file))
        deploy_quickstart(args, deploy_settings_file, network_settings_file,
                          args.inventory_file)
    else:
        ansible_args = {
            'virsh_enabled_networks': net_settings.enabled_network_list
        }
        utils.run_ansible(ansible_args,
                          os.path.join(args.deploy_dir, ANSIBLE_PATH,
                                       'deploy_dependencies.yml'))
        if args.virtual:
            # create all overcloud VMs
            build_vms(inventory, net_settings)
        else:
            # TODO(trozet) need to attach nics to  br-admin and br-external
            # for baremetal deploy
            pass
        # Dump all settings out to temp bash files to be sourced
        instackenv_json = os.path.join(APEX_TEMP_DIR, INVENTORY_FILE)
        with open(instackenv_json, 'w') as fh:
            json.dump(inventory, fh)
        deploy_bash_file = os.path.join(APEX_TEMP_DIR, 'deploy_settings.sh')
        deploy_settings.dump_bash(os.path.join(APEX_TEMP_DIR,
                                               'deploy_settings.sh'))
        logging.info("File created: {}".format(deploy_bash_file))
        net_bash_file = os.path.join(APEX_TEMP_DIR, 'network_settings.sh')
        net_settings.dump_bash(os.path.join(net_bash_file))
        logging.info("File created: {}".format(net_bash_file))

        deploy_bash()
