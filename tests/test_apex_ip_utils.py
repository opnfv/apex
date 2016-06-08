import sys 
import re

from apex.ip_utils import IPUtilsException
from apex.ip_utils import get_interface
from apex.ip_utils import find_gateway
from apex.ip_utils import get_ip
from apex.ip_utils import get_ip_range

from nose.tools import assert_equal
from nose.tools import assert_not_equal
from nose.tools import assert_raises
from nose.tools import assert_is_instance
from nose.tools import assert_regexp_matches
from nose.tools import raises

from ipaddress import IPv4Address
from ipaddress import IPv6Address



def get_default_gateway_linux():
    """Read the default gateway directly from /proc."""
    with open("/proc/net/route") as fh:
        for line in fh:
            fields = line.strip().split()
            if fields[2] not in ('00000000', 'Gateway'):
                return fields[0]


class TestIpUtils(object):
    @classmethod
    def setup_class(klass):
        """This method is run once for each class before any tests are run"""
        klass.iface_name = get_default_gateway_linux()
        iface = get_interface(klass.iface_name)
        klass.iface = iface
        iface = get_interface('lo')
        klass.lo_iface = iface

    @classmethod
    def teardown_class(klass):
        """This method is run once for each class _after_ all tests are run"""

    def setUp(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_get_interface(self):
        assert_equal(get_interface(''), None)
        assert_equal(get_interface('notreal'), None)
        assert_is_instance(get_interface(
                               self.iface_name,
                               address_family=4), IPv4Address)
        assert_is_instance(get_interface(
                               self.iface_name,
                               address_family=6), IPv6Address)
        assert_raises(IPUtilsException,
                      get_interface, self.iface_name, 0)

    def test_find_gateway(self):
        assert_is_instance(find_gateway(self.iface), str)
        iface_virbr0 = get_interface('virbr0')
        assert_equal(find_gateway(iface_virbr0), None)

    def test_get_ip(self):
        ip4_pattern = re.compile('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
        assert_equal(get_ip(1, cidr="10.10.10.0/24"), "0")
        assert_regexp_matches(get_ip(1, interface=self.iface), ip4_pattern)
        assert_raises(IPUtilsException, get_ip, 1)


    def test_get_ip_range(self):
        ip4_pattern = re.compile('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3},\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
        assert_raises(IPUtilsException, get_ip_range)
        assert_raises(IPUtilsException, get_ip_range, interface=self.iface)
        assert_regexp_matches(get_ip_range(interface=self.iface, start_offset=1, end_offset=20), ip4_pattern)
        assert_regexp_matches(get_ip_range(interface=self.iface, start_offset=1, count=10), ip4_pattern)
        assert_regexp_matches(get_ip_range(interface=self.iface, end_offset=20, count=10), ip4_pattern)
        # cidr is an object I think, but I haven't figured out how to instantiate one
        #assert_raises(IPUtilsException, get_ip_range, cidr="10.10.10.0/24")
        #assert_regexp_matches(get_ip_range(cidr="10.10.10.0/24", start_offset=1, end_offset=20), ip4_pattern)
        #assert_regexp_matches(get_ip_range(cidr="10.10.10.0/24", start_offset=1, count=10), ip4_pattern)
        #assert_regexp_matches(get_ip_range(cidr="10.10.10.0/24", end_offset=20, count=10), ip4_pattern)
