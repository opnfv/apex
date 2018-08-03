##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

from mock import patch
from mock import MagicMock
import os
import unittest
import urllib.request

from apex.common import exceptions as exc
from apex.overcloud.node import OvercloudNode
from apex.settings.deploy_settings import DeploySettings
from apex.tests.constants import TEST_DUMMY_CONFIG

DUMMY_SNAP_DIR = '/tmp/dummy_cache'


class TestSnapshotDeployment(unittest.TestCase):
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

    @patch('apex.overcloud.node.OvercloudNode.create')
    @patch('apex.overcloud.node.os.path.isfile')
    @patch('apex.overcloud.node.libvirt.open')
    def test_init(self, mock_libvirt_open, mock_is_file, mock_node_create):
        mock_is_file.return_value = True
        OvercloudNode(role='controller', ip='123.123.123.123',
                      ovs_ctrlrs=None, ovs_mgrs=None,
                      name='dummy-controller-0', node_xml='dummynode.xml',
                      disk_img='dummy.qcow2')
        mock_node_create.assert_called()

    @patch('apex.overcloud.node.OvercloudNode.create')
    @patch('apex.overcloud.node.libvirt.open')
    def test_init_invalid_files(self, mock_libvirt_open, mock_node_create):
        self.assertRaises(exc.OvercloudNodeException,
                          OvercloudNode, 'controller', '123.123.123',
                          None, None, 'dummy-controller-0', 'dummynode.xml',
                          'dummy.qcow2')

    @patch('apex.overcloud.node.shutil.copyfile')
    @patch('apex.overcloud.node.OvercloudNode.create')
    @patch('apex.overcloud.node.os.path.isfile')
    @patch('apex.overcloud.node.libvirt.open')
    def test_configure_disk(self, mock_libvirt_open, mock_is_file,
                            mock_node_create, mock_copy):
        mock_is_file.return_value = True
        node = OvercloudNode(role='controller', ip='123.123.123.123',
                             ovs_ctrlrs=None, ovs_mgrs=None,
                             name='dummy-controller-0',
                             node_xml='dummynode.xml',
                             disk_img='dummy.qcow2')
        conn = mock_libvirt_open.return_value
        conn.storagePoolLookupByName.return_value.XMLDesc.return_value = """
        <pool type='dir'>
          <target>
            <path>/var/lib/libvirt/images</path>
          </target>
        </pool>
        """
        node._configure_disk('dummy.qcow2')
        mock_copy.assert_called()
        self.assertEqual(node.disk_img, '/var/lib/libvirt/images/dummy.qcow2')

    @patch('apex.overcloud.node.shutil.copyfile')
    @patch('apex.overcloud.node.OvercloudNode.create')
    @patch('apex.overcloud.node.os.path.isfile')
    @patch('apex.overcloud.node.libvirt.open')
    def test_configure_disk_bad_path(self, mock_libvirt_open, mock_is_file,
                                     mock_node_create, mock_copy):
        mock_is_file.return_value = True
        node = OvercloudNode(role='controller', ip='123.123.123.123',
                             ovs_ctrlrs=None, ovs_mgrs=None,
                             name='dummy-controller-0',
                             node_xml='dummynode.xml',
                             disk_img='dummy.qcow2')
        conn = mock_libvirt_open.return_value
        conn.storagePoolLookupByName.return_value.XMLDesc.return_value = """
        <pool type='dir'>
          <target>
          </target>
        </pool>
        """
        self.assertRaises(exc.OvercloudNodeException,
                          node._configure_disk, 'dummy.qcow2')

    @patch('apex.overcloud.node.shutil.copyfile')
    @patch('apex.overcloud.node.OvercloudNode.create')
    @patch('apex.overcloud.node.os.path.isfile')
    @patch('apex.overcloud.node.libvirt.open')
    def test_configure_disk_no_pool(self, mock_libvirt_open, mock_is_file,
                                    mock_node_create, mock_copy):
        mock_is_file.return_value = True
        node = OvercloudNode(role='controller', ip='123.123.123.123',
                             ovs_ctrlrs=None, ovs_mgrs=None,
                             name='dummy-controller-0',
                             node_xml='dummynode.xml',
                             disk_img='dummy.qcow2')
        conn = mock_libvirt_open.return_value
        conn.storagePoolLookupByName.return_value = None
        self.assertRaises(exc.OvercloudNodeException,
                          node._configure_disk, 'dummy.qcow2')

    @patch('apex.overcloud.node.distro.linux_distribution')
    def test_update_xml(self, mock_linux_distro):
        mock_linux_distro.return_value = ['Fedora']
        xml_file = os.path.join(TEST_DUMMY_CONFIG, 'baremetal0.xml')
        with open(xml_file, 'r') as fh:
            xml = fh.read()
        new_xml = OvercloudNode._update_xml(
            xml=xml, disk_path='/dummy/disk/path/blah.qcow2')
        self.assertIn('/dummy/disk/path/blah.qcow2', new_xml)
        self.assertIn('/usr/bin/qemu-kvm', new_xml)

    @patch('apex.overcloud.node.distro.linux_distribution')
    def test_update_xml_no_disk(self, mock_linux_distro):
        mock_linux_distro.return_value = ['Fedora']
        xml_file = os.path.join(TEST_DUMMY_CONFIG, 'baremetal0.xml')
        with open(xml_file, 'r') as fh:
            xml = fh.read()
        new_xml = OvercloudNode._update_xml(xml=xml)
        self.assertIn('/home/images/baremetal0.qcow2', new_xml)
        self.assertIn('/usr/bin/qemu-kvm', new_xml)

