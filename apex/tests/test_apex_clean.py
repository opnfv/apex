##############################################################################
# Copyright (c) 2016 Tim Rozet (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import mock
import os
import pyipmi
import pyipmi.chassis
from mock import patch
from nose.tools import (
    assert_raises,
    assert_equal
)

from apex import clean_nodes
from apex import clean
from apex.tests import constants as con


class dummy_domain:

    def isActive(self):
        return True

    def destroy(self):
        pass

    def undefine(self):
        pass


class dummy_vol:

    def wipe(self, *args):
        pass

    def delete(self, *args):
        pass


class dummy_pool:

    def storageVolLookupByName(self, *args, **kwargs):
        return dummy_vol()

    def refresh(self):
        pass


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

    @patch('virtualbmc.manager.VirtualBMCManager.list',
           return_value=[{'domain_name': 'dummy1'}, {'domain_name': 'dummy2'}])
    @patch('virtualbmc.manager.VirtualBMCManager.delete')
    def test_vmbc_clean(self, vbmc_del_func, vbmc_list_func):
        assert clean.clean_vbmcs() is None

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

    @patch('libvirt.open')
    def test_clean_vms(self, mock_libvirt):
        ml = mock_libvirt.return_value
        ml.storagePoolLookupByName.return_value = dummy_pool()
        ml.listDefinedDomains.return_value = ['undercloud']
        ml.lookupByName.return_value = dummy_domain()
        assert clean.clean_vms() is None

    @patch('apex.network.jumphost.detach_interface_from_ovs')
    @patch('apex.network.jumphost.remove_ovs_bridge')
    @patch('libvirt.open')
    def test_clean_networks(self, mock_libvirt, mock_jumphost_ovs_remove,
                            mock_jumphost_detach):
        ml = mock_libvirt.return_value
        ml.listNetworks.return_value = ['admin', 'external', 'tenant', 'blah']
        mock_net = ml.networkLookupByName.return_value
        mock_net.isActive.return_value = True
        clean.clean_networks()
        assert_equal(mock_net.destroy.call_count, 3)
