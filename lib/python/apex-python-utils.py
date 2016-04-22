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


def parse_net_settings(settings_args):
    settings = apex.NetworkSettings(settings_args.path,
                                    settings_args.network_isolation)
    settings.dump_bash()


def find_ip(int_args):
    interface = apex.ip_utils.get_interface(int_args.interface,
                                      int_args.address_family)
    if interface:
        print(interface.ip)


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

args = parser.parse_args(sys.argv[1:])
if args.DEBUG:
    logging.basicConfig(level=logging.DEBUG)

if hasattr(args, 'func'):
    args.func(args)
else:
    parser.print_help()
    exit(1)
