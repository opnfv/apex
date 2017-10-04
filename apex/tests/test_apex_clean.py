##############################################################################
# Copyright (c) 2016 Tim Rozet, Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import libvirt
import mock
import os
import pyipmi
import pyipmi.chassis

from mock import patch
from mock import MagicMock

from nose.tools import (
    assert_raises,
    assert_equal,
    assert_is_none
)

from apex import clean_nodes
from apex import clean
from apex.common.exceptions import ApexCleanException


class TestClean:
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

    def test_clean_nodes(self):
        with mock.patch.object(pyipmi.Session, 'establish') as mock_method:
            with patch.object(pyipmi.chassis.Chassis,
                              'chassis_control_power_down') as mock_method2:
                clean_nodes('apex/tests/config/inventory.yaml')

        assert_equal(mock_method.call_count, 5)
        assert_equal(mock_method2.call_count, 5)

    @patch('apex.clean.utils.parse_yaml')
    def test_clean_nodes_empty(self, mock_parse_yaml):
        mock_parse_yaml.return_value = None
        assert_raises(SystemExit, clean_nodes, 'dummy_file')
        mock_parse_yaml.return_value = {}
        assert_raises(SystemExit, clean_nodes, 'dummy_file')

    @patch('apex.clean.pyipmi.interfaces.create_interface')
    @patch('apex.clean.utils.parse_yaml')
    def test_clean_nodes_raises(self, mock_parse_yaml, mock_pyipmi):
        mock_parse_yaml.return_value = {'nodes': {'node': {}}}
        mock_pyipmi.side_effect = Exception()
        assert_raises(SystemExit, clean_nodes, 'dummy_file')

    @patch('virtualbmc.manager.VirtualBMCManager.list',
           return_value=[{'domain_name': 'dummy1'}, {'domain_name': 'dummy2'}])
    @patch('virtualbmc.manager.VirtualBMCManager.delete')
    def test_clean_vmbcs(self, vbmc_del_func, vbmc_list_func):
        assert_is_none(clean.clean_vbmcs())

    @patch('apex.clean.libvirt.open')
    def test_clean_vms(self, mock_libvirt):
        ml = mock_libvirt.return_value
        ml.storagePoolLookupByName.return_value = MagicMock()
        uc = MagicMock()
        uc.name.return_value = 'undercloud'
        x = MagicMock()
        x.name.return_value = 'domain_x'
        ml.listAllDomains.return_value = [uc, x]
        assert_is_none(clean.clean_vms())

    @patch('apex.clean.libvirt.open')
    def test_clean_vms_skip_vol(self, mock_libvirt):
        ml = mock_libvirt.return_value
        pool = ml.storagePoolLookupByName.return_value
        pool.storageVolLookupByName.side_effect = libvirt.libvirtError('msg')
        uc = MagicMock()
        uc.name.return_value = 'undercloud'
        ml.listAllDomains.return_value = [uc]
        clean.clean_vms()

    @patch('apex.clean.libvirt.open')
    def test_clean_vms_raises_clean_ex(self, mock_libvirt):
        mock_libvirt.return_value = None
        assert_raises(ApexCleanException, clean.clean_vms)

    def test_clean_ssh_keys(self):
        ssh_file = os.path.join(con.TEST_DUMMY_CONFIG, 'authorized_dummy')
        with open(ssh_file, 'w') as fh:
            fh.write('ssh-rsa 2LwlofGD8rNUFAlafY2/oUsKOf1mQ1 stack@undercloud')
        assert clean.clean_ssh_keys(ssh_file) is None
        with open(ssh_file, 'r') as fh:
            output = fh.read()
        assert 'stack@undercloud' not in output
        if os.path.isfile(ssh_file):
            os.remove(ssh_file)

    @patch('apex.clean.jumphost.detach_interface_from_ovs')
    @patch('apex.clean.jumphost.remove_ovs_bridge')
    @patch('apex.clean.libvirt.open')
    def test_clean_networks(self, mock_libvirt, mock_jumphost_ovs_remove,
                            mock_jumphost_detach):
        ml = mock_libvirt.return_value
        ml.listNetworks.return_value = ['admin', 'external', 'tenant', 'blah']
        mock_net = ml.networkLookupByName.return_value
        mock_net.isActive.return_value = True
        clean.clean_networks()
        assert_equal(mock_net.destroy.call_count, 3)

    @patch('apex.clean.jumphost.detach_interface_from_ovs')
    @patch('apex.clean.jumphost.remove_ovs_bridge')
    @patch('apex.clean.libvirt.open')
    def test_clean_networks_raises(self, mock_libvirt,
                                   mock_jumphost_ovs_remove,
                                   mock_jumphost_detach):
        mock_libvirt.return_value = False
        assert_raises(ApexCleanException, clean.clean_networks)

    @patch('apex.clean.clean_ssh_keys')
    @patch('apex.clean.clean_networks')
    @patch('apex.clean.clean_vbmcs')
    @patch('apex.clean.clean_vms')
    @patch('apex.clean.clean_nodes')
    @patch('apex.clean.os.path.isfile')
    @patch('apex.clean.os.makedirs')
    @patch('apex.clean.argparse')
    def test_main(self, mock_argparse, mock_mkdirs, mock_isfile,
                  mock_clean_nodes, mock_clean_vms, mock_clean_vbmcs,
                  mock_clean_networks, mock_clean_ssh_keys):
        clean.main()

    @patch('apex.clean.os.path.isfile')
    @patch('apex.clean.os.makedirs')
    @patch('apex.clean.argparse')
    def test_main_no_inv(self, mock_argparse, mock_mkdirs, mock_isfile):
        mock_isfile.return_value = False
        assert_raises(FileNotFoundError, clean.main)
