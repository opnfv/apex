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

from apex.common import exceptions as exc
from apex.deployment.snapshot import SnapshotDeployment
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

    @patch('apex.deployment.snapshot.SnapshotDeployment.pull_snapshot')
    @patch('apex.deployment.snapshot.libvirt.open')
    @patch('apex.deployment.snapshot.SnapshotDeployment.deploy_snapshot')
    def test_init(self, mock_deploy_snap, mock_libvirt_open, mock_pull_snap):

        ds_file = os.path.join(TEST_DUMMY_CONFIG, 'dummy-deploy-settings.yaml')
        ds = DeploySettings(ds_file)
        d = SnapshotDeployment(deploy_settings=ds,
                               snap_cache_dir=DUMMY_SNAP_DIR,
                               fetch=True, all_in_one=False)
        snap_dir = os.path.join(DUMMY_SNAP_DIR, 'queens', 'noha')
        self.assertEqual(d.snap_cache_dir, snap_dir)
        mock_pull_snap.assert_called()
        mock_deploy_snap.assert_called()
        self.assertEqual(d.ha_ext, 'noha')

    @patch('apex.deployment.snapshot.SnapshotDeployment.pull_snapshot')
    @patch('apex.deployment.snapshot.libvirt.open')
    @patch('apex.deployment.snapshot.SnapshotDeployment.deploy_snapshot')
    def test_init_allinone_no_fetch(self, mock_deploy_snap, mock_libvirt_open,
                                    mock_pull_snap):

        ds_file = os.path.join(TEST_DUMMY_CONFIG, 'dummy-deploy-settings.yaml')
        ds = DeploySettings(ds_file)
        d = SnapshotDeployment(deploy_settings=ds,
                               snap_cache_dir=DUMMY_SNAP_DIR,
                               fetch=False, all_in_one=True)
        snap_dir = os.path.join(DUMMY_SNAP_DIR, 'queens', 'noha-allinone')
        self.assertEqual(d.snap_cache_dir, snap_dir)
        mock_pull_snap.assert_not_called()
        mock_deploy_snap.assert_called()
        self.assertEqual(d.ha_ext, 'noha-allinone')

    @patch('apex.deployment.snapshot.utils.fetch_upstream_and_unpack')
    @patch('apex.deployment.snapshot.utils.fetch_properties')
    def test_pull_snapshot_is_latest(self, mock_fetch_props,
                                     mock_fetch_artifact):
        mock_fetch_props.return_value = {
            'OPNFV_SNAP_URL': 'artifacts.opnfv.org/apex/master/noha/'
                              'apex-csit-snap-2018-08-05.tar.gz',
            'OPNFV_SNAP_SHA512SUM': 'bb0c6fa0e675dcb39cfad11d81bb99f309d5cfc23'
                                    '6e36a74d05ee813584f3e5bb92aa23dec77584631'
                                    '7b75d574f8c86186c666f78a299c24fb68849897b'
                                    'dd4bc'
        }
        SnapshotDeployment.pull_snapshot('http://dummy_url',
                                         TEST_DUMMY_CONFIG)
        mock_fetch_artifact.assert_not_called()

    @patch('apex.deployment.snapshot.utils.fetch_upstream_and_unpack')
    @patch('apex.deployment.snapshot.utils.fetch_properties')
    def test_pull_snapshot_fetch_props_failure(self, mock_fetch_props,
                                               mock_fetch_artifact):
        mock_fetch_props.return_value = None
        self.assertRaisesRegex(exc.SnapshotDeployException,
                               'Unable to fetch upstream.*',
                               SnapshotDeployment.pull_snapshot,
                               'http://dummy_url', TEST_DUMMY_CONFIG)

    @patch('apex.deployment.snapshot.utils.fetch_upstream_and_unpack')
    @patch('apex.deployment.snapshot.utils.fetch_properties')
    def test_pull_snapshot_is_not_latest(self, mock_fetch_props,
                                         mock_fetch_artifact):
        mock_fetch_props.side_effect = [{
            'OPNFV_SNAP_URL': 'artifacts.opnfv.org/apex/master/noha/'
                              'apex-csit-snap-2018-08-05.tar.gz',
            'OPNFV_SNAP_SHA512SUM': '123c6fa0e675dcb39cfad11d81bb99f309d5cfc23'
                                    '6e36a74d05ee813584f3e5bb92aa23dec77584631'
                                    '7b75d574f8c86186c666f78a299c24fb68849897b'
                                    'dd4bc'},
            {
            'OPNFV_SNAP_URL': 'artifacts.opnfv.org/apex/master/noha/'
                              'apex-csit-snap-2018-08-05.tar.gz',
            'OPNFV_SNAP_SHA512SUM': 'bb0c6fa0e675dcb39cfad11d81bb99f309d5cfc23'
                                    '6e36a74d05ee813584f3e5bb92aa23dec77584631'
                                    '7b75d574f8c86186c666f78a299c24fb68849897b'
                                    'dd4bc'}]
        SnapshotDeployment.pull_snapshot('http://dummy_url',
                                         TEST_DUMMY_CONFIG)
        mock_fetch_artifact.assert_called()

    @patch('apex.deployment.snapshot.OvercloudNode')
    @patch('apex.deployment.snapshot.SnapshotDeployment.pull_snapshot')
    @patch('apex.deployment.snapshot.libvirt.open')
    @patch('apex.deployment.snapshot.SnapshotDeployment.deploy_snapshot')
    def test_parse_and_create_nodes(self, mock_deploy_snap, mock_libvirt_open,
                                    mock_pull_snap, mock_oc_node):
        ds_file = os.path.join(TEST_DUMMY_CONFIG, 'dummy-deploy-settings.yaml')
        ds = DeploySettings(ds_file)
        d = SnapshotDeployment(deploy_settings=ds,
                               snap_cache_dir=DUMMY_SNAP_DIR,
                               fetch=False, all_in_one=False)
        d.snap_cache_dir = TEST_DUMMY_CONFIG
        node = mock_oc_node()
        d.parse_and_create_nodes()
        node.start.assert_called()
        self.assertListEqual([node], d.oc_nodes)

    @patch('apex.deployment.snapshot.utils.parse_yaml')
    @patch('apex.deployment.snapshot.OvercloudNode')
    @patch('apex.deployment.snapshot.SnapshotDeployment.pull_snapshot')
    @patch('apex.deployment.snapshot.libvirt.open')
    @patch('apex.deployment.snapshot.SnapshotDeployment.deploy_snapshot')
    def test_parse_and_create_nodes_invalid_node_yaml(
            self, mock_deploy_snap, mock_libvirt_open, mock_pull_snap,
            mock_oc_node, mock_parse_yaml):
        ds_file = os.path.join(TEST_DUMMY_CONFIG, 'dummy-deploy-settings.yaml')
        ds = DeploySettings(ds_file)
        d = SnapshotDeployment(deploy_settings=ds,
                               snap_cache_dir=DUMMY_SNAP_DIR,
                               fetch=False, all_in_one=False)
        d.snap_cache_dir = TEST_DUMMY_CONFIG
        node = mock_oc_node()
        mock_parse_yaml.return_value = {'blah': 'dummy'}
        self.assertRaises(exc.SnapshotDeployException,
                          d.parse_and_create_nodes)
        node.start.assert_not_called()
