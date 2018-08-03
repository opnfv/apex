##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

from mock import patch
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

    
