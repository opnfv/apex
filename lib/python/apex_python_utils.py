##############################################################################
# Copyright (c) 2016 Feng Pan (fpan@redhat.com), Dan Radez (dradez@redhat.com)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import sys
import logging
import os
import yaml

from copy import copy

from jinja2 import Environment
from jinja2 import FileSystemLoader

from apex import NetworkSettings
from apex import NetworkEnvironment
from apex import DeploySettings
from apex import ip_utils
from apex.common.constants import ADMIN_NETWORK


def parse_net_settings(args):
    """
    Parse OPNFV Apex network_settings.yaml config file
    and dump bash syntax to set environment variables

    Args:
    - file: string
      file to network_settings.yaml file
    - network_isolation: bool
      enable or disable network_isolation
    """
    settings = NetworkSettings(args.net_settings_file,
                               args.network_isolation)
    net_env = NetworkEnvironment(settings, args.net_env_file,
                                 args.compute_pre_config,
                                 args.controller_pre_config)
    dump_yaml(net_env.get_netenv_settings(), '/tmp/network-environment.yaml')
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

    network_settings = NetworkSettings(args.net_settings_file,
                                       args.network_isolation)
    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template(template)

    # gather vlan values into a dict
    net_list = copy(args.enabled_networks).split(' ')
    net_list.remove(ADMIN_NETWORK)
    vlans_vals = map(lambda x: network_settings[x]['vlan'], net_list)
    vlans = dict(zip(net_list, vlans_vals))
    nics = network_settings.nics

    print(template.render(enabled_networks=args.enabled_networks,
                          role=args.role,
                          vlans=vlans,
                          external_net_type=args.ext_net_type,
                          external_net_af=args.address_family,
                          ovs_dpdk_bridge=args.ovs_dpdk_bridge,
                          nics=nics))


def get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('--debug', action='store_true', default=False,
                        help="Turn on debug messages")
    parser.add_argument('-l', '--log-file', default='/var/log/apex/apex.log',
                        dest='log_file', help="Log file to log to")
    subparsers = parser.add_subparsers()

    net_settings = subparsers.add_parser('parse-net-settings',
                                         help='Parse network settings file')
    net_settings.add_argument('-s', '--net-settings-file',
                              default='network-settings.yaml',
                              dest='net_settings_file',
                              help='path to network settings file')
    net_settings.add_argument('--flat', action='store_false',
                              default=True, dest='network_isolation',
                              help='disable network isolation')
    net_settings.add_argument('-e', '--net-env-file',
                              default="network-environment.yaml",
                              dest='net_env_file',
                              help='path to network environment file')
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

    get_int_ip = subparsers.add_parser('find-ip',
                                       help='Find interface ip')
    get_int_ip.add_argument('-i', '--interface', required=True,
                            help='Interface name')
    get_int_ip.add_argument('-af', '--address-family', default=4, type=int,
                            choices=[4, 6], dest='address_family',
                            help='IP Address family')
    get_int_ip.set_defaults(func=find_ip)

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
    nic_template.add_argument('--flat', action='store_false',
                              default=True, dest='network_isolation',
                              help='disable network isolation')
    nic_template.add_argument('-n', '--enabled-networks', required=True,
                              dest='enabled_networks',
                              help='enabled network list')
    nic_template.add_argument('-e', '--ext-net-type', default='interface',
                              dest='ext_net_type',
                              choices=['interface', 'br-ex'],
                              help='External network type')
    nic_template.add_argument('-af', '--address-family', type=int, default=4,
                              dest='address_family', help='IP address family')
    nic_template.add_argument('-d', '--ovs-dpdk-bridge',
                              default=None, dest='ovs_dpdk_bridge',
                              help='OVS DPDK Bridge Name')
    nic_template.set_defaults(func=build_nic_template)

    deploy_settings = subparsers.add_parser('parse-deploy-settings',
                                            help='Parse deploy settings file')
    deploy_settings.add_argument('-f', '--file',
                                 default='deploy_settings.yaml',
                                 help='path to deploy settings file')
    deploy_settings.set_defaults(func=parse_deploy_settings)

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
