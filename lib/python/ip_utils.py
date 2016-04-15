
##############################################################################
# Copyright (c) 2016 Feng Pan (fpan@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


import ipaddress


def generate_ip_range(args):
    """
    Generate IP range in string format for given CIDR.
    This function works for both IPv4 and IPv6.

    args is expected to contain the following members:
    CIDR: any valid CIDR representation.
    start_position: starting index, default to first address in subnet (1)
    end_position:  ending index, default to last address in subnet (-1)

    Returns IP range in string format. A single IP is returned if start and end IPs are identical.
    """
    cidr = ipaddress.ip_network(args.CIDR)
    (start_index, end_index) = (args.start_position, args.end_position)
    if cidr[start_index] == cidr[end_index]:
        return str(cidr[start_index])
    else:
        return ','.join(sorted([str(cidr[start_index]), str(cidr[end_index])]))


def main():
    import argparse
    import sys

    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    parser_gen_ip_range = subparsers.add_parser('generate_ip_range', help='Generate IP Range given CIDR')
    parser_gen_ip_range.add_argument('CIDR', help='Network in CIDR notation')
    parser_gen_ip_range.add_argument('start_position', type=int, help='Starting index')
    parser_gen_ip_range.add_argument('end_position', type=int, help='Ending index')
    parser_gen_ip_range.set_defaults(func=generate_ip_range)

    args = parser.parse_args(sys.argv[1:])
    print(args.func(args))


if __name__ == '__main__':
    main()

