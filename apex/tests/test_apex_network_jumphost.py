##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os
import shutil
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

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=[])
    def test_attach_interface(self, dump_ports_func, is_bridge_func,
                              subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-enpfakes0'))
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-br-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        jumphost.NET_CFG_PATH = ifcfg_dir
        output = jumphost.attach_interface_to_ovs('br-admin', 'enpfakes0',
                                                  'admin')
        assert output is None
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-enpfakes0'))
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-enpfakes0.orig'))

        for ifcfg in ('ifcfg-enpfakes0', 'ifcfg-enpfakes0.orig',
                      'ifcfg-br-admin'):
            ifcfg_path = os.path.join(ifcfg_dir, ifcfg)
            if os.path.isfile(ifcfg_path):
                os.remove(ifcfg_path)

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=['dummy_int'])
    def test_already_attached_interface(self, dump_ports_func, is_bridge_func,
                                        subprocess_func):
        output = jumphost.attach_interface_to_ovs('br-dummy', 'dummy_int',
                                                  'admin')
        assert output is None

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=[])
    def test_negative_attach_interface(self, dump_ports_func, is_bridge_func,
                                       subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        jumphost.NET_CFG_PATH = ifcfg_dir
        assert_raises(FileNotFoundError, jumphost.attach_interface_to_ovs,
                      'br-dummy', 'dummy_int', 'admin')

    @patch('subprocess.check_call', side_effect=subprocess_exception)
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=[])
    def test_negative_attach_interface_process_error(
            self, dump_ports_func, is_bridge_func, subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-enpfakes0'))
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-br-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        jumphost.NET_CFG_PATH = ifcfg_dir
        assert_raises(subprocess.CalledProcessError,
                      jumphost.attach_interface_to_ovs,
                      'br-admin', 'enpfakes0', 'admin')
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-enpfakes0'))
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-enpfakes0.orig'))

        for ifcfg in ('ifcfg-enpfakes0', 'ifcfg-enpfakes0.orig',
                      'ifcfg-br-admin'):
            ifcfg_path = os.path.join(ifcfg_dir, ifcfg)
            if os.path.isfile(ifcfg_path):
                os.remove(ifcfg_path)

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=['enpfakes0'])
    def test_detach_interface(self, dump_ports_func, is_bridge_func,
                              subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-br-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        jumphost.NET_CFG_PATH = ifcfg_dir
        output = jumphost.detach_interface_from_ovs('admin')
        assert output is None
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-enpfakes0'))
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-br-admin'))

        for ifcfg in ('ifcfg-enpfakes0', 'ifcfg-enpfakes0.orig',
                      'ifcfg-br-admin'):
            ifcfg_path = os.path.join(ifcfg_dir, ifcfg)
            if os.path.isfile(ifcfg_path):
                os.remove(ifcfg_path)

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=['enpfakes0'])
    def test_detach_interface_orig_exists(self, dump_ports_func,
                                          is_bridge_func, subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-br-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-enpfakes0.orig'))
        jumphost.NET_CFG_PATH = ifcfg_dir
        output = jumphost.detach_interface_from_ovs('admin')
        assert output is None
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-enpfakes0'))
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        assert not os.path.isfile(os.path.join(ifcfg_dir,
                                               'ifcfg-enpfakes0.orig'))
        for ifcfg in ('ifcfg-enpfakes0', 'ifcfg-enpfakes0.orig',
                      'ifcfg-br-admin'):
            ifcfg_path = os.path.join(ifcfg_dir, ifcfg)
            if os.path.isfile(ifcfg_path):
                os.remove(ifcfg_path)

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=False)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=[])
    def test_detach_interface_no_bridge(self, dump_ports_func,
                                        is_bridge_func, subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        jumphost.NET_CFG_PATH = ifcfg_dir
        output = jumphost.detach_interface_from_ovs('admin')
        assert output is None

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=[])
    def test_detach_interface_no_int_to_remove(self, dump_ports_func,
                                               is_bridge_func,
                                               subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        jumphost.NET_CFG_PATH = ifcfg_dir
        output = jumphost.detach_interface_from_ovs('admin')
        assert output is None

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=['enpfakes0'])
    def test_negative_detach_interface(self, dump_ports_func, is_bridge_func,
                                       subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        jumphost.NET_CFG_PATH = ifcfg_dir
        assert_raises(FileNotFoundError, jumphost.detach_interface_from_ovs,
                      'admin')

    @patch('subprocess.check_call', side_effect=subprocess_exception)
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    @patch('apex.network.jumphost.dump_ovs_ports', return_value=['enpfakes0'])
    def test_negative_detach_interface_process_error(
            self, dump_ports_func, is_bridge_func, subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-br-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        jumphost.NET_CFG_PATH = ifcfg_dir
        assert_raises(subprocess.CalledProcessError,
                      jumphost.detach_interface_from_ovs, 'admin')
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-enpfakes0'))
        assert os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-br-admin'))

        for ifcfg in ('ifcfg-enpfakes0', 'ifcfg-enpfakes0.orig',
                      'ifcfg-br-admin'):
            ifcfg_path = os.path.join(ifcfg_dir, ifcfg)
            if os.path.isfile(ifcfg_path):
                os.remove(ifcfg_path)

    @patch('subprocess.check_call')
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    def test_remove_ovs_bridge(self, is_bridge_func, subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        jumphost.NET_CFG_PATH = ifcfg_dir
        shutil.copyfile(os.path.join(ifcfg_dir, 'ifcfg-br-dummy'),
                        os.path.join(ifcfg_dir, 'ifcfg-br-admin'))
        assert jumphost.remove_ovs_bridge(apex_constants.ADMIN_NETWORK) is None
        assert not os.path.isfile(os.path.join(ifcfg_dir, 'ifcfg-br-admin'))

        # test without file
        assert jumphost.remove_ovs_bridge(apex_constants.ADMIN_NETWORK) is None

    @patch('subprocess.check_call', side_effect=subprocess_exception)
    @patch('apex.network.jumphost.is_ovs_bridge', return_value=True)
    def test_negative_remove_ovs_bridge(self, is_bridge_func, subprocess_func):
        ifcfg_dir = con.TEST_DUMMY_CONFIG
        jumphost.NET_CFG_PATH = ifcfg_dir
        assert_raises(subprocess.CalledProcessError,
                      jumphost.remove_ovs_bridge,
                      apex_constants.ADMIN_NETWORK)
