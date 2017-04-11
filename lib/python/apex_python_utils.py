##############################################################################
# Copyright (c) 2016 Feng Pan (fpan@redhat.com), Dan Radez (dradez@redhat.com)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import apex
import argparse
import sys
import logging
import os
import yaml

from jinja2 import Environment
from jinja2 import FileSystemLoader

from apex import NetworkSettings
from apex import NetworkEnvironment
from apex import DeploySettings
from apex import Inventory
from apex import ip_utils


def parse_net_settings(args):
    """
    Parse OPNFV Apex network_settings.yaml config file
    and dump bash syntax to set environment variables

    Args:
    - file: string
      file to network_settings.yaml file
    """
    settings = NetworkSettings(args.net_settings_file)
    net_env = NetworkEnvironment(settings, args.net_env_file,
                                 args.compute_pre_config,
                                 args.controller_pre_config)
    target = args.target_dir.split('/')
    target.append('network-environment.yaml')
    dump_yaml(dict(net_env), '/'.join(target))
    settings.dump_bash()


def dump_yaml(data, file):
    """
    Dumps data to a file as yaml
    :param data: yaml to be written to file
    :param file: filename to write to
    :return:
    """
    with open(file, "w") as fh:
        yaml.dump(data, fh, default_flow_style=False)


def parse_deploy_settings(args):
    settings = DeploySettings(args.file)
    settings.dump_bash()


def run_clean(args):
    apex.clean_nodes(args.file)


def parse_inventory(args):
    inventory = Inventory(args.file, ha=args.ha, virtual=args.virtual)
    if args.export_bash is True:
        inventory.dump_bash()
    else:
        inventory.dump_instackenv_json()


def find_ip(args):
    """
    Get and print the IP from a specific interface

    Args:
    - interface: string
      network interface name
    - address_family: int
      4 or 6, respective to ipv4 or ipv6
    """
    interface = ip_utils.get_interface(args.interface,
                                       args.address_family)
    if interface:
        print(interface.ip)


def build_nic_template(args):
    """
    Build and print a Triple-O nic template from jinja template

    Args:
    - template: string
      path to jinja template to load
    - enabled_networks: comma delimited list
      list of networks defined in net_env.py
    - ext_net_type: string
      interface or br-ex, defines the external network configuration
    - address_family: string
      4 or 6, respective to ipv4 or ipv6
    - ovs_dpdk_bridge: string
      bridge name to use as ovs_dpdk
    """
    template_dir, template = args.template.rsplit('/', 1)

    netsets = NetworkSettings(args.net_settings_file)
    nets = netsets.get('networks')
    ds = DeploySettings(args.deploy_settings_file).get('deploy_options')
    env = Environment(loader=FileSystemLoader(template_dir), autoescape=True)
    template = env.get_template(template)

    if ds['dataplane'] == 'fdio':
        nets['tenant']['nic_mapping'][args.role]['phys_type'] = 'vpp_interface'
        nets['external'][0]['nic_mapping'][args.role]['phys_type'] =\
            'vpp_interface'
    if ds.get('performance', {}).get(args.role.title(), {}).get('vpp', {})\
            .get('uio-driver'):
        nets['tenant']['nic_mapping'][args.role]['uio-driver'] =\
            ds['performance'][args.role.title()]['vpp']['uio-driver']
        nets['external'][0]['nic_mapping'][args.role]['uio-driver'] =\
            ds['performance'][args.role.title()]['vpp']['uio-driver']
    if ds.get('performance', {}).get(args.role.title(), {}).get('vpp', {})\
            .get('interface-options'):
        nets['tenant']['nic_mapping'][args.role]['interface-options'] =\
            ds['performance'][args.role.title()]['vpp']['interface-options']

    print(template.render(nets=nets,
                          role=args.role,
                          external_net_af=netsets.get_ip_addr_family(),
                          external_net_type=args.ext_net_type,
                          ovs_dpdk_bridge=args.ovs_dpdk_bridge))


def get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('--debug', action='store_true', default=False,
                        help="Turn on debug messages")
    parser.add_argument('-l', '--log-file', default='/var/log/apex/apex.log',
                        dest='log_file', help="Log file to log to")
    subparsers = parser.add_subparsers()
    # parse-net-settings
    net_settings = subparsers.add_parser('parse-net-settings',
                                         help='Parse network settings file')
    net_settings.add_argument('-s', '--net-settings-file',
                              default='network-settings.yaml',
                              dest='net_settings_file',
                              help='path to network settings file')
    net_settings.add_argument('-e', '--net-env-file',
                              default="network-environment.yaml",
                              dest='net_env_file',
                              help='path to network environment file')
    net_settings.add_argument('-td', '--target-dir',
                              default="/tmp",
                              dest='target_dir',
                              help='directory to write the'
                                   'network-environment.yaml file')
    net_settings.add_argument('--compute-pre-config',
                              default=False,
                              action='store_true',
                              dest='compute_pre_config',
                              help='Boolean to enable Compute Pre Config')
    net_settings.add_argument('--controller-pre-config',
                              action='store_true',
                              default=False,
                              dest='controller_pre_config',
                              help='Boolean to enable Controller Pre Config')

    net_settings.set_defaults(func=parse_net_settings)
    # find-ip
    get_int_ip = subparsers.add_parser('find-ip',
                                       help='Find interface ip')
    get_int_ip.add_argument('-i', '--interface', required=True,
                            help='Interface name')
    get_int_ip.add_argument('-af', '--address-family', default=4, type=int,
                            choices=[4, 6], dest='address_family',
                            help='IP Address family')
    get_int_ip.set_defaults(func=find_ip)
    # nic-template
    nic_template = subparsers.add_parser('nic-template',
                                         help='Build NIC templates')
    nic_template.add_argument('-r', '--role', required=True,
                              choices=['controller', 'compute'],
                              help='Role template generated for')
    nic_template.add_argument('-t', '--template', required=True,
                              dest='template',
                              help='Template file to process')
    nic_template.add_argument('-s', '--net-settings-file',
                              default='network-settings.yaml',
                              dest='net_settings_file',
                              help='path to network settings file')
    nic_template.add_argument('-e', '--ext-net-type', default='interface',
                              dest='ext_net_type',
                              choices=['interface', 'vpp_interface', 'br-ex'],
                              help='External network type')
    nic_template.add_argument('-d', '--ovs-dpdk-bridge',
                              default=None, dest='ovs_dpdk_bridge',
                              help='OVS DPDK Bridge Name')
    nic_template.add_argument('--deploy-settings-file',
                              help='path to deploy settings file')

    nic_template.set_defaults(func=build_nic_template)
    # parse-deploy-settings
    deploy_settings = subparsers.add_parser('parse-deploy-settings',
                                            help='Parse deploy settings file')
    deploy_settings.add_argument('-f', '--file',
                                 default='deploy_settings.yaml',
                                 help='path to deploy settings file')
    deploy_settings.set_defaults(func=parse_deploy_settings)
    # parse-inventory
    inventory = subparsers.add_parser('parse-inventory',
                                      help='Parse inventory file')
    inventory.add_argument('-f', '--file',
                           default='deploy_settings.yaml',
                           help='path to deploy settings file')
    inventory.add_argument('--ha',
                           default=False,
                           action='store_true',
                           help='Indicate if deployment is HA or not')
    inventory.add_argument('--virtual',
                           default=False,
                           action='store_true',
                           help='Indicate if deployment inventory is virtual')
    inventory.add_argument('--export-bash',
                           default=False,
                           dest='export_bash',
                           action='store_true',
                           help='Export bash variables from inventory')
    inventory.set_defaults(func=parse_inventory)

    clean = subparsers.add_parser('clean',
                                  help='Parse deploy settings file')
    clean.add_argument('-f', '--file',
                       help='path to inventory file')
    clean.set_defaults(func=run_clean)

    return parser


def main():
    parser = get_parser()
    args = parser.parse_args(sys.argv[1:])
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        apex_log_filename = args.log_file
        os.makedirs(os.path.dirname(apex_log_filename), exist_ok=True)
        logging.basicConfig(filename=apex_log_filename,
                            format='%(asctime)s %(levelname)s: %(message)s',
                            datefmt='%m/%d/%Y %I:%M:%S %p',
                            level=logging.DEBUG)
    if hasattr(args, 'func'):
        args.func(args)
    else:
        parser.print_help()
        exit(1)

if __name__ == "__main__":
    main()
