##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import os
import unittest

from mock import patch
from mock import Mock
from mock import MagicMock
from mock import mock_open

from apex.common.exceptions import ApexDeployException
from apex.common.constants import DEFAULT_OS_VERSION
from apex.deploy import validate_cross_settings
from apex.deploy import build_vms
from apex.deploy import create_deploy_parser
from apex.deploy import validate_deploy_args
from apex.deploy import main
from apex.tests.constants import TEST_DUMMY_CONFIG

from nose.tools import (
    assert_is_instance,
    assert_regexp_matches,
    assert_raises,
    assert_equal)

a_mock_open = mock_open(read_data=None)


class TestDeploy(unittest.TestCase):
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

    def test_validate_cross_settings(self):
        deploy_settings = {'deploy_options': {'dataplane': 'ovs'}}
        net_settings = Mock()
        net_settings.enabled_network_list = ['tenant']
        validate_cross_settings(deploy_settings, net_settings, '')

    def test_validate_cross_settings_raises(self):
        deploy_settings = {'deploy_options': {'dataplane': 'notovs'}}
        net_settings = Mock()
        net_settings.enabled_network_list = []
        assert_raises(ApexDeployException,
                      validate_cross_settings,
                      deploy_settings, net_settings, None)

    @patch('apex.deploy.virt_utils')
    @patch('apex.deploy.vm_lib')
    def test_build_vms(self, mock_vm_lib, mock_virt_utils):
        inventory = {'nodes': [{'memory': '1234',
                                'cpu': '4',
                                'mac': 'mac_addr',
                                'pm_port': 1234}]}
        net_sets = Mock()
        net_sets.enabled_network_list = []
        build_vms(inventory, net_sets)

    def test_create_deploy_parser(self):
        assert_is_instance(create_deploy_parser(), argparse.ArgumentParser)

    @patch('apex.deploy.os.path')
    def test_validate_deploy_args(self, mock_os_path):
        mock_os_path.isfile.return_value = True
        args = Mock()
        args.inventory_file = None
        args.virtual = True
        args.snapshot = False
        validate_deploy_args(args)

    def test_validate_snapshot_deploy_args(self):
        args = Mock()
        args.deploy_settings_file = os.path.join(TEST_DUMMY_CONFIG,
                                                 'dummy-deploy-settings.yaml')
        args.inventory_file = None
        args.virtual = True
        args.snapshot = True
        validate_deploy_args(args)

    def test_validate_deploy_args_no_virt_no_inv(self):
        args = Mock()
        args.inventory_file = 'file_name'
        args.virtual = False
        args.snapshot = False
        assert_raises(ApexDeployException, validate_deploy_args, args)

    @patch('apex.deploy.os.path')
    def test_validate_deploy_args_w_virt_raises(self, mock_os_path):
        mock_os_path.isfile.return_value = False
        args = Mock()
        args.inventory_file = None
        args.virtual = True
        args.snapshot = False
        assert_raises(ApexDeployException, validate_deploy_args, args)

    def test_validate_deploy_args_virt_and_inv_file(self):
        args = Mock()
        args.inventory_file = 'file_name'
        args.virtual = True
        args.snapshot = False
        assert_raises(ApexDeployException, validate_deploy_args, args)

    @patch('apex.deploy.oc_builder')
    @patch('apex.deploy.ApexDeployment')
    @patch('apex.deploy.uc_builder')
    @patch('apex.deploy.network_data.create_network_data')
    @patch('apex.deploy.shutil')
    @patch('apex.deploy.oc_deploy')
    @patch('apex.deploy.uc_lib')
    @patch('apex.deploy.build_vms')
    @patch('apex.deploy.Inventory')
    @patch('apex.deploy.virt_utils')
    @patch('apex.deploy.oc_cfg')
    @patch('apex.deploy.parsers')
    @patch('apex.deploy.utils')
    @patch('apex.deploy.NetworkEnvironment')
    @patch('apex.deploy.NetworkSettings')
    @patch('apex.deploy.DeploySettings')
    @patch('apex.deploy.os')
    @patch('apex.deploy.json')
    @patch('apex.deploy.jumphost')
    @patch('apex.deploy.validate_cross_settings')
    @patch('apex.deploy.validate_deploy_args')
    @patch('apex.deploy.create_deploy_parser')
    @patch('builtins.open', a_mock_open, create=True)
    def test_main(self, mock_parser, mock_val_args, mock_cross_sets,
                  mock_jumphost, mock_json, mock_os,
                  mock_deploy_sets, mock_net_sets, mock_net_env,
                  mock_utils, mock_parsers, mock_oc_cfg,
                  mock_virt_utils, mock_inv, mock_build_vms, mock_uc_lib,
                  mock_oc_deploy, mock_shutil, mock_network_data,
                  mock_uc_builder, mock_deployment, mock_oc_builder):
        net_sets_dict = {'networks': MagicMock(),
                         'dns_servers': 'test'}
        ds_opts_dict = {'global_params': MagicMock(),
                        'deploy_options': {'gluon': False,
                                           'congress': True,
                                           'sdn_controller': 'opendaylight',
                                           'dataplane': 'ovs',
                                           'sfc': False,
                                           'vpn': False,
                                           'vim': 'openstack',
                                           'yardstick': 'test',
                                           'os_version': DEFAULT_OS_VERSION,
                                           'containers': False}}
        args = mock_parser.return_value.parse_args.return_value
        args.virtual = False
        args.quickstart = False
        args.debug = False
        args.snapshot = False
        args.upstream = True
        net_sets = mock_net_sets.return_value
        net_sets.enabled_network_list = ['external']
        net_sets.__getitem__.side_effect = net_sets_dict.__getitem__
        net_sets.__contains__.side_effect = net_sets_dict.__contains__
        deploy_sets = mock_deploy_sets.return_value
        deploy_sets.__getitem__.side_effect = ds_opts_dict.__getitem__
        deploy_sets.__contains__.side_effect = ds_opts_dict.__contains__
        mock_parsers.parse_nova_output.return_value = {'testnode1': 'test'}
        main()

    @patch('apex.deploy.SnapshotDeployment')
    @patch('apex.deploy.validate_cross_settings')
    @patch('apex.deploy.virt_utils')
    @patch('apex.deploy.utils')
    @patch('apex.deploy.Inventory')
    @patch('apex.deploy.NetworkEnvironment')
    @patch('apex.deploy.NetworkSettings')
    @patch('apex.deploy.DeploySettings')
    @patch('apex.deploy.os')
    @patch('apex.deploy.create_deploy_parser')
    @patch('builtins.open', a_mock_open, create=True)
    def test_main_snapshot(self, mock_parser, mock_os, mock_deploy,
                           mock_net_sets, mock_net_env, mock_inv, mock_utils,
                           mock_virt_utils, mock_cross, mock_snap_deployment):
        args = mock_parser.return_value.parse_args.return_value
        args.virtual = False
        args.snapshot = True
        args.debug = True
        main()
        mock_snap_deployment.assert_called()

    @patch('apex.deploy.oc_builder')
    @patch('apex.deploy.ApexDeployment')
    @patch('apex.deploy.uc_builder')
    @patch('apex.deploy.network_data.create_network_data')
    @patch('apex.deploy.shutil')
    @patch('apex.deploy.oc_deploy')
    @patch('apex.deploy.uc_lib')
    @patch('apex.deploy.build_vms')
    @patch('apex.deploy.Inventory')
    @patch('apex.deploy.virt_utils')
    @patch('apex.deploy.oc_cfg')
    @patch('apex.deploy.parsers')
    @patch('apex.deploy.utils')
    @patch('apex.deploy.NetworkEnvironment')
    @patch('apex.deploy.NetworkSettings')
    @patch('apex.deploy.DeploySettings')
    @patch('apex.deploy.os')
    @patch('apex.deploy.json')
    @patch('apex.deploy.jumphost')
    @patch('apex.deploy.validate_cross_settings')
    @patch('apex.deploy.validate_deploy_args')
    @patch('apex.deploy.create_deploy_parser')
    @patch('builtins.open', a_mock_open, create=True)
    def test_main_virt(self, mock_parser, mock_val_args, mock_cross_sets,
                       mock_jumphost, mock_json, mock_os,
                       mock_deploy_sets, mock_net_sets, mock_net_env,
                       mock_utils, mock_parsers, mock_oc_cfg,
                       mock_virt_utils, mock_inv, mock_build_vms, mock_uc_lib,
                       mock_oc_deploy, mock_shutil, mock_network_data,
                       mock_uc_builder, mock_deployment, mock_oc_builder):
        # didn't work yet line 412
        # net_sets_dict = {'networks': {'admin': {'cidr': MagicMock()}},
        #                 'dns_servers': 'test'}
        # net_sets_dict['networks']['admin']['cidr'].return_value.version = 6
        ds_opts_dict = {'global_params': MagicMock(),
                        'deploy_options': {'gluon': False,
                                           'congress': False,
                                           'sdn_controller': 'opendaylight',
                                           'dataplane': 'ovs',
                                           'sfc': False,
                                           'vpn': False,
                                           'vim': 'openstack',
                                           'yardstick': 'test',
                                           'os_version': DEFAULT_OS_VERSION,
                                           'containers': False}}
        args = mock_parser.return_value.parse_args.return_value
        args.virtual = True
        args.quickstart = False
        args.debug = True
        args.virt_default_ram = 10
        args.ha_enabled = True
        args.virt_compute_nodes = 1
        args.virt_compute_ram = None
        args.virt_default_ram = 12
        args.upstream = True
        args.snapshot = False
        net_sets = mock_net_sets.return_value
        net_sets.enabled_network_list = ['admin']
        deploy_sets = mock_deploy_sets.return_value
        deploy_sets.__getitem__.side_effect = ds_opts_dict.__getitem__
        deploy_sets.__contains__.side_effect = ds_opts_dict.__contains__
        main()
        args.virt_compute_ram = 16
        args.virt_default_ram = 10
        main()

    @patch('apex.deploy.ApexDeployment')
    @patch('apex.deploy.c_builder')
    @patch('apex.deploy.uc_builder')
    @patch('apex.deploy.oc_builder')
    @patch('apex.deploy.network_data.create_network_data')
    @patch('apex.deploy.shutil')
    @patch('apex.deploy.oc_deploy')
    @patch('apex.deploy.uc_lib')
    @patch('apex.deploy.build_vms')
    @patch('apex.deploy.Inventory')
    @patch('apex.deploy.virt_utils')
    @patch('apex.deploy.oc_cfg')
    @patch('apex.deploy.parsers')
    @patch('apex.deploy.utils')
    @patch('apex.deploy.NetworkEnvironment')
    @patch('apex.deploy.NetworkSettings')
    @patch('apex.deploy.DeploySettings')
    @patch('apex.deploy.os')
    @patch('apex.deploy.json')
    @patch('apex.deploy.jumphost')
    @patch('apex.deploy.validate_cross_settings')
    @patch('apex.deploy.validate_deploy_args')
    @patch('apex.deploy.create_deploy_parser')
    @patch('builtins.open', a_mock_open, create=True)
    def test_main_virt_containers_upstream(
            self, mock_parser, mock_val_args, mock_cross_sets, mock_jumphost,
            mock_json, mock_os, mock_deploy_sets, mock_net_sets, mock_net_env,
            mock_utils, mock_parsers, mock_oc_cfg, mock_virt_utils,
            mock_inv, mock_build_vms, mock_uc_lib, mock_oc_deploy,
            mock_shutil, mock_network_data, mock_oc_builder,
            mock_uc_builder, mock_c_builder, mock_deployment):

        ds_opts_dict = {'global_params': MagicMock(),
                        'deploy_options': {'gluon': False,
                                           'congress': False,
                                           'sdn_controller': 'opendaylight',
                                           'dataplane': 'ovs',
                                           'sfc': False,
                                           'vpn': False,
                                           'vim': 'openstack',
                                           'yardstick': 'test',
                                           'os_version': DEFAULT_OS_VERSION,
                                           'containers': True}}
        args = mock_parser.return_value.parse_args.return_value
        args.virtual = True
        args.quickstart = False
        args.debug = True
        args.virt_default_ram = 10
        args.ha_enabled = True
        args.virt_compute_nodes = 1
        args.virt_compute_ram = None
        args.virt_default_ram = 12
        args.upstream = True
        args.snapshot = False
        net_sets = mock_net_sets.return_value
        net_sets.enabled_network_list = ['admin']
        deploy_sets = mock_deploy_sets.return_value
        deploy_sets.__getitem__.side_effect = ds_opts_dict.__getitem__
        deploy_sets.__contains__.side_effect = ds_opts_dict.__contains__
        main()
        args.virt_compute_ram = 16
        args.virt_default_ram = 10
        main()
        mock_oc_deploy.prep_image.assert_called()
        # TODO(trozet) add assertions here with arguments for functions in
        # deploy main

    @patch('apex.deploy.oc_builder')
    @patch('apex.deploy.ApexDeployment')
    @patch('apex.deploy.uc_builder')
    @patch('apex.deploy.network_data.create_network_data')
    @patch('apex.deploy.shutil')
    @patch('apex.deploy.git')
    @patch('apex.deploy.oc_deploy')
    @patch('apex.deploy.uc_lib')
    @patch('apex.deploy.build_vms')
    @patch('apex.deploy.Inventory')
    @patch('apex.deploy.virt_utils')
    @patch('apex.deploy.oc_cfg')
    @patch('apex.deploy.parsers')
    @patch('apex.deploy.utils')
    @patch('apex.deploy.NetworkEnvironment')
    @patch('apex.deploy.NetworkSettings')
    @patch('apex.deploy.DeploySettings')
    @patch('apex.deploy.os')
    @patch('apex.deploy.json')
    @patch('apex.deploy.jumphost')
    @patch('apex.deploy.validate_cross_settings')
    @patch('apex.deploy.validate_deploy_args')
    @patch('apex.deploy.create_deploy_parser')
    @patch('builtins.open', a_mock_open, create=True)
    def test_main_k8s(self, mock_parser, mock_val_args, mock_cross_sets,
                      mock_jumphost, mock_json, mock_os,
                      mock_deploy_sets, mock_net_sets, mock_net_env,
                      mock_utils, mock_parsers, mock_oc_cfg,
                      mock_virt_utils, mock_inv, mock_build_vms, mock_uc_lib,
                      mock_oc_deploy, mock_git, mock_shutil,
                      mock_network_data, mock_uc_builder, mock_deployment,
                      mock_oc_builder):
        net_sets_dict = {'networks': MagicMock(),
                         'dns_servers': 'test'}
        ds_opts_dict = {'global_params': MagicMock(),
                        'deploy_options': {'gluon': False,
                                           'congress': True,
                                           'sdn_controller': False,
                                           'dataplane': 'ovs',
                                           'sfc': False,
                                           'vpn': False,
                                           'vim': 'k8s',
                                           'yardstick': 'test',
                                           'os_version': DEFAULT_OS_VERSION,
                                           'containers': False}}
        args = mock_parser.return_value.parse_args.return_value
        args.virtual = False
        args.quickstart = False
        args.debug = False
        args.upstream = False
        args.snapshot = False
        net_sets = mock_net_sets.return_value
        net_sets.enabled_network_list = ['external']
        net_sets.__getitem__.side_effect = net_sets_dict.__getitem__
        net_sets.__contains__.side_effect = net_sets_dict.__contains__
        deploy_sets = mock_deploy_sets.return_value
        deploy_sets.__getitem__.side_effect = ds_opts_dict.__getitem__
        deploy_sets.__contains__.side_effect = ds_opts_dict.__contains__
        mock_parsers.parse_nova_output.return_value = {'testnode1': 'test'}
        main()
