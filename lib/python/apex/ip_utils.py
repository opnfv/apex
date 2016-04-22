##############################################################################
# Copyright (c) 2016 Feng Pan (fpan@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


import ipaddress
import subprocess
import re
import logging


def get_ip_range(start_offset=None, count=None, end_offset=None,
                 cidr=None, interface=None):
    """
    Generate IP range for a network (cidr) or an interface.

    If CIDR is provided, it will take precedence over interface. In this case,
    The entire CIDR IP address space is considered usable. start_offset will be
    calculated from the network address, and end_offset will be calculated from
    the last address in subnet.

    If interface is provided, the interface IP will be used to calculate
    offsets:
        - If the interface IP is in the first half of the address space,
        start_offset will be calculated from the interface IP, and end_offset
        will be calculated from end of address space.
        - If the interface IP is in the second half of the address space,
        start_offset will be calculated from the network address in the address
        space, and end_offset will be calculated from the interface IP.

    2 of start_offset, end_offset and count options must be provided:
        - If start_offset and end_offset are provided, a range from start_offset
        to end_offset will be returned.
        - If count is provided, a range from eithe start_offset to (start_offset
        +count) or (end_offset-count) to end_offset will be returned. The
        IP range returned will be of size <count>.
    Both start_offset and end_offset must be greater than 0.

    Returns IP range in the format of "first_addr,second_addr" or exception
    is raised.
    """
    if cidr:
        if count and start_offset and not end_offset:
            start_index = start_offset
            end_index = start_offset + count -1
        elif count and end_offset and not start_offset:
            end_index = -1 - end_offset
            start_index = -1 - end_index - count + 1
        elif start_offset and end_offset and not count:
            start_index = start_offset
            end_index = -1 - end_offset
        else:
            raise IPUtilsException("Argument error: must pass in exactly 2 of"
                                   "start_offset, end_offset and count")

        start_ip = cidr[start_index]
        end_ip = cidr[end_index]
        network = cidr
    elif interface:
        network = interface.network
        number_of_addr = network.num_addresses
        if interface.ip < network[int(number_of_addr / 2)]:
            if count and start_offset and not end_offset:
                start_ip = interface.ip + start_offset
                end_ip = start_ip + count - 1
            elif count and end_offset and not start_offset:
                end_ip = network[-1 - end_offset]
                start_ip = end_ip - count + 1
            elif start_offset and end_offset and not count:
                start_ip = interface.ip + start_offset
                end_ip = network[-1 - end_offset]
            else:
                raise IPUtilsException(
                    "Argument error: must pass in exactly 2 of"
                    "start_offset, end_offset and count")
        else:
            if count and start_offset and not end_offset:
                start_ip = network[start_offset]
                end_ip = start_ip + count -1
            elif count and end_offset and not start_offset:
                end_ip = interface.ip - end_offset
                start_ip = end_ip - count + 1
            elif start_offset and end_offset and not count:
                start_ip = network[start_offset]
                end_ip = interface.ip - end_offset
            else:
                raise IPUtilsException(
                    "Argument error: must pass in exactly 2 of"
                    "start_offset, end_offset and count")

    else:
        raise IPUtilsException("Must pass in cidr or interface to generate"
                               "ip range")

    range_result = validate_ip_range(start_ip, end_ip, network)
    if range_result == 0:
        ip_range = "{},{}".format(start_ip, end_ip)
        return ip_range
    else:
        raise IPUtilsException(range_result)


def get_ip(offset, cidr=None, interface=None):
    """
    Returns an IP in a network given an offset.

    Either cidr or interface must be provided, cidr takes precedence.

    If cidr is provided, offset is calculated from network address.
    If interface is provided, offset is calculated from interface IP.

    offset can be positive or negative, but the resulting IP address must also
    be contained in the same subnet, otherwise an exception will be raised.

    returns a IP address object.
    """
    if cidr:
        ip = cidr[0 + offset]
        network = cidr
    elif interface:
        ip = interface.ip + offset
        network = interface.network
    else:
        raise IPUtilsException("Must pass in cidr or interface to generate IP")

    if ip not in network:
        raise IPUtilsException("IP {} not in network {}".format(ip, network))
    else:
        return str(ip)


def generate_ip_range(args):
    """
    Generate IP range in string format for given CIDR.
    This function works for both IPv4 and IPv6.

    args is expected to contain the following members:
    CIDR: any valid CIDR representation.
    start_position: starting index, default to first address in subnet (1)
    end_position:  ending index, default to last address in subnet (-1)

    Returns IP range in string format. A single IP is returned if start and
    end IPs are identical.
    """
    cidr = ipaddress.ip_network(args.CIDR)
    (start_index, end_index) = (args.start_position, args.end_position)
    if cidr[start_index] == cidr[end_index]:
        return str(cidr[start_index])
    else:
        return ','.join(sorted([str(cidr[start_index]), str(cidr[end_index])]))


def get_interface(nic, address_family=4):
    """
    Returns interface object for a given NIC name in the system

    Only global address will be returned at the moment.

    Returns interface object if an address is found for the given nic,
    otherwise returns None.
    """
    if not nic.strip():
        logging.error("empty nic name specified")
        return None
    output = subprocess.getoutput("ip -{} addr show {} scope global"
                                  .format(address_family, nic))
    if address_family == 4:
        pattern = re.compile("\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}")
    elif address_family == 6:
        pattern = re.compile("([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}/\d{1,3}")
    else:
        raise IPUtilsException("Invalid address family: {}"
                               .format(address_family))
    match = re.search(pattern, output)
    if match:
        logging.info("found interface {} ip: {}".format(nic, match.group()))
        return ipaddress.ip_interface(match.group())
    else:
        logging.info("interface ip not found! ip address output:\n{}"
                        .format(output))
        return None


def find_gateway(interface):
    """
    Validate gateway on the system

    Ensures that the provided interface object is in fact configured as default
    route on the system.

    Returns gateway IP (reachable from interface) if default route is found,
    otherwise returns None.
    """

    address_family = interface.version
    output = subprocess.getoutput("ip -{} route".format(address_family))

    pattern = re.compile("default\s+via\s+(\S+)\s+")
    match = re.search(pattern, output)

    if match:
        gateway_ip = match.group(1)
        reverse_route_output = subprocess.getoutput("ip route get {}"
                                                    .format(gateway_ip))
        pattern = re.compile("{}.+src\s+{}".format(gateway_ip, interface.ip))
        if not re.search(pattern, reverse_route_output):
            logging.warning("Default route doesn't match iterface specified: {}"
                            .format(reverse_route_output))
            return None
        else:
            return gateway_ip
    else:
        logging.warning("Can't find gateway address on system")
        return None


def validate_ip_range(start_ip, end_ip, cidr):
    """
    Validates an IP range is in good order and the range is part of cidr.

    Returns 0 if validation succeeds, or reason for failure in string.
    """
    ip_range = "{},{}".format(start_ip, end_ip)
    if end_ip <= start_ip:
        return ("IP range {} is invalid: end_ip should be greater than starting"
                " ip".format(ip_range))
    if start_ip not in ipaddress.ip_network(cidr):
        return 'start_ip {} is not in network {}'.format(start_ip, cidr)
    if end_ip not in ipaddress.ip_network(cidr):
        return 'end_ip {} is not in network {}'.format(end_ip, cidr)

    return 0


class IPUtilsException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return self.value
