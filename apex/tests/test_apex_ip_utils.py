##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import ipaddress
import re
from ipaddress import IPv4Address
from ipaddress import ip_network

from nose.tools import (
    assert_equal,
    assert_false,
    assert_is_instance,
    assert_raises,
    assert_regexp_matches,
    assert_true)

from apex.network.ip_utils import (
    IPUtilsException,
    _validate_ip_range,
    find_gateway,
    get_interface,
    get_ip,
    get_ip_range)

ip4_pattern = re.compile('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
ip4_range_pattern = re.compile('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3},\d{1,'
                               '3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')


def get_default_gateway_linux():
    """Read the default gateway directly from /proc."""
    with open("/proc/net/route") as fh:
        for line in fh:
            fields = line.strip().split()
            if fields[2] not in ('00000000', 'Gateway'):
                return fields[0]


class TestIpUtils:
    @classmethod
    def setup_class(cls):
        """This method is run once for each class before any tests are run"""
        cls.iface_name = get_default_gateway_linux()
        iface = get_interface(cls.iface_name)
        cls.iface = iface

    @classmethod
    def teardown_class(cls):
        """This method is run once for each class _after_ all tests are run"""

    def setup(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_get_interface(self):
        assert_equal(get_interface(''), None)
        assert_equal(get_interface('notreal'), None)
        assert_is_instance(get_interface(self.iface_name,
                                         address_family=4),
                           IPv4Address)
        # can't enable this until there's a v6 address on the ci hosts
        # assert_is_instance(get_interface(
        #                       self.iface_name,
        #                       address_family=6), IPv6Address)
        assert_raises(IPUtilsException,
                      get_interface, self.iface_name, 0)

    def test_find_gateway(self):
        assert_is_instance(find_gateway(self.iface), str)

    def test_get_ip(self):
        cidr = ipaddress.ip_network("10.10.10.0/24")
        assert_equal(get_ip(1, cidr=cidr), "10.10.10.1")
        assert_raises(IPUtilsException, get_ip, 1000, interface=self.iface)
        assert_regexp_matches(get_ip(1, interface=self.iface), ip4_pattern)
        assert_raises(IPUtilsException, get_ip, 1)

    def test_get_ip_range_raises(self):
        assert_raises(IPUtilsException, get_ip_range)
        assert_raises(IPUtilsException, get_ip_range, interface=self.iface)

    def test_get_ip_range_with_interface(self):
        assert_regexp_matches(get_ip_range(interface=self.iface,
                                           start_offset=1, end_offset=20),
                              ip4_range_pattern)
        assert_regexp_matches(get_ip_range(interface=self.iface,
                                           start_offset=1, count=10),
                              ip4_range_pattern)
        assert_regexp_matches(get_ip_range(interface=self.iface, end_offset=20,
                                           count=10), ip4_range_pattern)

    def test_get_ip_range_with_cidr(self):
        cidr = ip_network('10.10.10.0/24')
        assert_raises(IPUtilsException, get_ip_range, cidr=cidr)
        assert_regexp_matches(get_ip_range(cidr=cidr, start_offset=1,
                                           end_offset=20), ip4_pattern)
        assert_regexp_matches(get_ip_range(cidr=cidr, start_offset=1,
                                           count=10), ip4_pattern)
        assert_regexp_matches(get_ip_range(cidr=cidr, end_offset=20,
                                           count=10), ip4_pattern)

    def test__validate_ip_range(self):
        cidr = ip_network('10.10.10.0/24')
        assert_true(_validate_ip_range(
                    start_ip=ipaddress.IPv4Address('10.10.10.1'),
                    end_ip=ipaddress.IPv4Address('10.10.10.10'),
                    cidr=cidr))
        assert_false(_validate_ip_range(
                     start_ip=ipaddress.IPv4Address('10.10.10.10'),
                     end_ip=ipaddress.IPv4Address('10.10.10.1'),
                     cidr=cidr))
        assert_false(_validate_ip_range(
                     start_ip=ipaddress.IPv4Address('10.10.0.1'),
                     end_ip=ipaddress.IPv4Address('10.10.10.10'),
                     cidr=cidr))
        assert_false(_validate_ip_range(
                     start_ip=ipaddress.IPv4Address('10.10.10.1'),
                     end_ip=ipaddress.IPv4Address('10.10.11.10'),
                     cidr=cidr))

    def test_exception(self):
        e = IPUtilsException("test")
        print(e)
        assert_is_instance(e, IPUtilsException)
