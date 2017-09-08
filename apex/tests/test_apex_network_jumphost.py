##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os
import subprocess

from apex import NetworkSettings
from apex.tests import constants as con
from apex.common import constants as apex_constants
from apex.network import jumphost
from apex.common.exceptions import JumpHostNetworkException
from ipaddress import IPv4Interface
from mock import patch
from nose.tools import (
    assert_is_instance,
    assert_dict_equal,
    assert_raises,
    assert_true,
    assert_false
)


def bridge_show_output(*args, **kwargs):
    return b"""
    b6f1b54a-b8ba-4e86-9c5b-733ab71b5712
    Bridge br-admin
        Port br-admin
            Interface br-admin
                type: internal
    ovs_version: "2.5.0"
"""


def bridge_port_list(*args, **kwargs):
    return b"""
enp6s0
vnet1
"""


def subprocess_exception(*args, **kwargs):
    raise subprocess.CalledProcessError(returncode=2, cmd='dummy')


class TestNetworkJumpHost:
    @classmethod
    def setup_class(cls):
        """This method is run once for each class before any tests are run"""

    @classmethod
    def teardown_class(cls):
        """This method is run once for each class _after_ all tests are run"""

    def setup(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    @patch('subprocess.check_output', side_effect=bridge_show_output)
    def test_is_ovs_bridge(self, bridge_output_function):
        assert_true(jumphost.is_ovs_bridge('br-admin'))
        assert_false(jumphost.is_ovs_bridge('br-blah'))

    @patch('subprocess.check_output', side_effect=bridge_port_list)
    def test_dump_ovs_ports(self, bridge_function):
        output = jumphost.dump_ovs_ports('br-admin')
        assert_is_instance(output, list)
        assert 'enp6s0' in output

    def test_generate_ifcfg_params(self):
        output = jumphost.generate_ifcfg_params(
            os.path.join(con.TEST_DUMMY_CONFIG, 'ifcfg-br-external'),
            apex_constants.EXTERNAL_NETWORK)
        assert_is_instance(output, dict)
        assert output['IPADDR'] == '172.30.9.66'
        assert output['PEERDNS'] == 'no'

    def test_negative_generate_ifcfg_params(self):
        assert_raises(JumpHostNetworkException, jumphost.generate_ifcfg_params,
                      os.path.join(con.TEST_DUMMY_CONFIG,
                                   'bad_ifcfg-br-external'),
                      apex_constants.EXTERNAL_NETWORK)

    @patch('subprocess.check_call')
    @patch('apex.network.ip_utils.get_interface', return_value=IPv4Interface(
        '10.10.10.2'))
    def test_configure_bridges_ip_exists(self, interface_function,
                                         subprocess_func):
        ns = NetworkSettings(os.path.join(con.TEST_CONFIG_DIR,
                                          'network', 'network_settings.yaml'))
        assert jumphost.configure_bridges(ns) is None

    @patch('subprocess.check_call')
    @patch('apex.network.ip_utils.get_interface', return_value=None)
    def test_configure_bridges_no_ip(self, interface_function,
                                     subprocess_func):
        ns = NetworkSettings(os.path.join(con.TEST_CONFIG_DIR,
                                          'network', 'network_settings.yaml'))
        assert jumphost.configure_bridges(ns) is None

    @patch('subprocess.check_call', side_effect=subprocess_exception)
    @patch('apex.network.ip_utils.get_interface', return_value=None)
    def test_negative_configure_bridges(self, interface_function,
                                        subprocess_func):
        ns = NetworkSettings(os.path.join(con.TEST_CONFIG_DIR,
                                          'network', 'network_settings.yaml'))
        assert_raises(subprocess.CalledProcessError,
                      jumphost.configure_bridges, ns)
