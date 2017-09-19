##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import libvirt
import unittest

from mock import patch

from apex.virtual.configure_vm import generate_baremetal_macs
from apex.virtual.configure_vm import create_vm_storage
from apex.virtual.configure_vm import create_vm

from nose.tools import (
    assert_regexp_matches,
    assert_raises,
    assert_equal)


class TestVirtualConfigureVM(unittest.TestCase):
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

    def test_generate_baremetal_macs(self):
        assert_regexp_matches(generate_baremetal_macs()[0],
                              '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')

    def test_generate_baremetal_macs_alot(self):
        assert_equal(len(generate_baremetal_macs(127)), 127)

    def test_generate_baremetal_macs_too_many(self):
        assert_raises(ValueError, generate_baremetal_macs, 128)

    @patch('apex.virtual.configure_vm.libvirt.open')
    def test_create_vm_storage(self, mock_libvirt_open):
        # setup mock
        conn = mock_libvirt_open.return_value
        pool = conn.storagePoolLookupByName.return_value
        pool.isActive.return_value = 0
        # execute
        create_vm_storage('test')

    @patch('apex.virtual.configure_vm.libvirt.open')
    def test_create_vm_storage_pool_none(self, mock_libvirt_open):
        # setup mock
        conn = mock_libvirt_open.return_value
        conn.storagePoolLookupByName.return_value = None
        # execute
        assert_raises(Exception, create_vm_storage, 'test')

    @patch('apex.virtual.configure_vm.libvirt.open')
    def test_create_vm_storage_libvirt_error(self, mock_libvirt_open):
        # setup mock
        conn = mock_libvirt_open.return_value
        pool = conn.storagePoolLookupByName.return_value
        pool.storageVolLookupByName.side_effect = libvirt.libvirtError('ermsg')
        # execute
        assert_raises(libvirt.libvirtError, create_vm_storage, 'test')

    @patch('apex.virtual.configure_vm.libvirt.open')
    def test_create_vm_storage_new_vol_none(self, mock_libvirt_open):
        # setup mock
        conn = mock_libvirt_open.return_value
        pool = conn.storagePoolLookupByName.return_value
        pool.createXML.return_value = None
        # execute
        assert_raises(Exception, create_vm_storage, 'test')

    @patch('apex.virtual.configure_vm.libvirt.open')
    @patch('apex.virtual.configure_vm.create_vm_storage')
    def test_create_vm(self, mock_create_vm_storage,
                       mock_libvirt_open):
        create_vm('test', 'image', default_network=True,
                  direct_boot=True, kernel_args='test', template_dir='./build')

    @patch('apex.virtual.configure_vm.libvirt.open')
    @patch('apex.virtual.configure_vm.create_vm_storage')
    def test_create_vm_x86_64(self, mock_create_vm_storage,
                              mock_libvirt_open):
        create_vm('test', 'image', arch='x86_64', template_dir='./build')

    @patch('apex.virtual.configure_vm.libvirt.open')
    @patch('apex.virtual.configure_vm.create_vm_storage')
    def test_create_vm_aarch64(self, mock_create_vm_storage,
                               mock_libvirt_open):
        create_vm('test', 'image', arch='aarch64', template_dir='./build')
