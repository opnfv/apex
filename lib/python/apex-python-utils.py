##############################################################################
# Copyright (c) 2016 Feng Pan (fpan@redhat.com)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


import argparse
import sys
import apex
import logging
import os
import yaml

from jinja2 import Environment, FileSystemLoader
from apex.net_env import PRIVATE_NETWORK, STORAGE_NETWORK, API_NETWORK


def parse_net_settings(settings_args):
    settings = apex.NetworkSettings()
    settings.load(settings_args.path,
                  settings_args.network_isolation)
    settings.dump_bash()


def find_ip(int_args):
    interface = apex.ip_utils.get_interface(int_args.interface,
                                      int_args.address_family)
    if interface:
        print(interface.ip)


def build_nic_template(nic_args):
    """
    Render and print a network template
    """
    env = Environment(loader=FileSystemLoader(nic_args.template_directory))
    template = env.get_template(nic_args.template_filename)
    print(template.render(enabled_networks=nic_args.enabled_networks,
                          external_net_type=nic_args.ext_net_type,
                          external_net_af=nic_args.address_family))

def build_netenv_template(args):
    """
    Load the network-environment.yaml file and modify its contents
    then pretty print the yaml output
    """
    netsets = apex.NetworkSettings()
    netsets.load_pickle64(args.network_settings)
    settings = netsets.settings_obj
    with open('/'.join([args.template_directory, args.template_filename]), 'r') as stream:
        netenv = yaml.load(stream)

    # update admin/provisioning and public/external network settings
    netenv['parameter_defaults']['ControlPlaneSubnetCidr'] = settings['admin_network']['cidr'].prefixlen
    netenv['parameter_defaults']['ControlPlaneDefaultRoute'] = settings['admin_network']['provisioner_ip']
    netenv['parameter_defaults']['ExternalNetCidr'] = str(settings['public_network']['cidr'])
    netenv['parameter_defaults']['ExternalAllocationPools'] = [{'start': settings['public_network']['usable_ip_range'].split(',')[0],
                                                                'end': settings['public_network']['usable_ip_range'].split(',')[1]}]
    netenv['parameter_defaults']['ExternalInterfaceDefaultRoute'] = settings['public_network']['gateway']
    netenv['parameter_defaults']['EC2MetadataIp'] = settings['admin_network']['provisioner_ip']
    # dns not implimented yet
    #netenv['parameter_defaults']['DnsServers'] = settings.DNSSERVERS?
    #DnsServers: ["8.8.8.8","8.8.4.4"]

    # check for the others
    if PRIVATE_NETWORK in args.enabled_networks:
        # resource registry updates
        for i in ['OS::TripleO::Network::Tenant',
                  'OS::TripleO::Controller::Ports::TenantPort',
                  'OS::TripleO::Compute::Ports::TenantPort']:
            netenv['resource_registry'][i] = netenv['resource_registry'][i].replace('noop', 'tenant')
        # default parameter updates
        netenv['parameter_defaults']['TenantNetCidr'] = str(settings.private_network.cidr)
        netenv['parameter_defaults']['TenantAllocationPools'] = [{'start': settings.private_network.usable_ip_range.split(',')[0],
                                                                  'end': settings.private_network.usable_ip_range.split(',')[1]}]

    if STORAGE_NETWORK in args.enabled_networks:
        # resource registry updates
        for i in ['OS::TripleO::Network::Storage',
                  'OS::TripleO::Network::Ports::StorageVipPort',
                  'OS::TripleO::Controller::Ports::StoragePort',
                  'OS::TripleO::Compute::Ports::StoragePort']:
            netenv['resource_registry'][i] = netenv['resource_registry'][i].replace('noop', 'storage')

        # default parameter updates
        netenv['parameter_defaults']['StorageNetCidr'] = str(settings.storage_network.cidr)
        netenv['parameter_defaults']['StorageAllocationPools'] = [{'start': settings.storage_network.usable_ip_range.split(',')[0],
                                                                   'end': settings.storage_network.usable_ip_range.split(',')[1]}]

    if API_NETWORK in args.enabled_networks:
        # API_NETWORK not implimented here
        # needed for IPv6?
        pass

    print(yaml.dump(netenv, default_flow_style=False))

parser = argparse.ArgumentParser()
parser.add_argument('--DEBUG', action='store_true', default=False,
                    help="Turn on debug messages")
subparsers = parser.add_subparsers()

net_settings = subparsers.add_parser('parse_net_settings',
                                     help='Parse network settings file')
net_settings.add_argument('-n', '--path', default='network_settings.yaml',
                          help='path to network settings file')
net_settings.add_argument('-i', '--network_isolation', type=bool, default=True,
                          help='network isolation')
net_settings.set_defaults(func=parse_net_settings)

get_int_ip = subparsers.add_parser('find_ip',
                                   help='Find interface ip')
get_int_ip.add_argument('-i', '--interface', required=True,
                        help='Interface name')
get_int_ip.add_argument('-af', '--address_family', default=4, type=int,
                        choices=[4, 6],
                        help='IP Address family')
get_int_ip.set_defaults(func=find_ip)

nic_template = subparsers.add_parser('nic_template', help='Build NIC templates')
nic_template.add_argument('-d', '--template_directory', required=True,
                          help='Template file directory')
nic_template.add_argument('-f', '--template_filename', required=True,
                          help='Template file to process')
nic_template.add_argument('-n', '--enabled_networks', required=True,
                          help='enabled network list')
nic_template.add_argument('-e', '--ext_net_type', default='interface',
                          choices=['interface', 'br-ex'],
                          help='External network type')
nic_template.add_argument('-af', '--address_family', type=int, default=4,
                          help='IP address family')
nic_template.set_defaults(func=build_nic_template)

netenv_template = subparsers.add_parser('netenv-template', help='Build NIC templates')
netenv_template.add_argument('-d', '--template-directory', dest='template_directory', required=True,
                             help='Template file directory')
netenv_template.add_argument('-f', '--template-filename', dest='template_filename', required=True,
                             help='Template file to process')
netenv_template.add_argument('--network-settings', dest='network_settings', required=True,
                             help='A pickled and base64 encoded NetworkSettings object')
netenv_template.add_argument('-n', '--enabled_networks', required=True,
                             help='enabled network list')
netenv_template.set_defaults(func=build_netenv_template)

args = parser.parse_args(sys.argv[1:])
if args.DEBUG:
    logging.basicConfig(level=logging.DEBUG)
else:
    apex_log_filename = '/var/log/apex/apex.log'
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
