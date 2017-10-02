##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import unittest

from mock import patch
from mock import MagicMock
from mock import mock_open

from apex.common import constants as con
from apex.common.exceptions import ApexDeployException
from apex.overcloud.deploy import build_sdn_env_list
from apex.overcloud.deploy import _get_node_counts
from apex.overcloud.deploy import create_deploy_cmd
from apex.overcloud.deploy import prep_image
from apex.overcloud.deploy import make_ssh_key
from apex.overcloud.deploy import prep_env
from apex.overcloud.deploy import generate_ceph_key
from apex.overcloud.deploy import prep_storage_env
from apex.overcloud.deploy import external_network_cmds
from apex.overcloud.deploy import create_congress_cmds

from nose.tools import (
    assert_regexp_matches,
    assert_raises,
    assert_equal)


class TestOvercloudDeploy(unittest.TestCase):
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

    def test_build_sdn_env_list(self):
        ds = {'sdn_controller': 'opendaylight'}
        sdn_map = {'opendaylight': 'test'}
        res = '/usr/share/openstack-tripleo-heat-templates/environments/test'
        assert_equal(build_sdn_env_list(ds, sdn_map), [res])

    def test_build_sdn_env_list_dict(self):
        ds = {'opendaylight': True,
              'sdn_controller': None}
        sdn_map = {'opendaylight': {}}
        assert_equal(build_sdn_env_list(ds, sdn_map), [])

    def test_build_sdn_env_list_tuple(self):
        ds = {'opendaylight': 'test',
              'sdn_controller': None}
        sdn_map = {'opendaylight': ('test', 'test')}
        res = '/usr/share/openstack-tripleo-heat-templates/environments/test'
        assert_equal(build_sdn_env_list(ds, sdn_map), [res])

    def test_get_node_counts(self):
        inv = {'nodes': [{'capabilities': 'profile:control'},
                         {'capabilities': 'profile:compute'}]}
        assert_equal(_get_node_counts(inv), (1, 1))

    def test_get_node_counts_empty_inv(self):
        assert_raises(ApexDeployException, _get_node_counts, None)

    def test_get_node_counts_invalid_capability(self):
        inv = {'nodes': [{'capabilities': 'invalid'}]}
        assert_raises(ApexDeployException, _get_node_counts, inv)

    @patch('apex.overcloud.deploy._get_node_counts')
    @patch('apex.overcloud.deploy.prep_storage_env')
    @patch('apex.overcloud.deploy.build_sdn_env_list')
    @patch('builtins.open', mock_open())
    def test_create_deploy_cmd(self, mock_sdn_list, mock_prep_storage,
                               mock_node_counts):
        mock_sdn_list.return_value = []
        mock_node_counts.return_value = (1, 2)
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ds['deploy_options'].__getitem__.side_effect = \
            lambda i: True if i == 'congress' else MagicMock()
        ds['deploy_options'].__contains__.side_effect = \
            lambda i: True if i == 'congress' else MagicMock()
        ns = {'ntp': ['ntp']}
        inv = None
        virt = True
        create_deploy_cmd(ds, ns, inv, '/tmp', virt)

    @patch('apex.overcloud.deploy._get_node_counts')
    @patch('apex.overcloud.deploy.prep_storage_env')
    @patch('apex.overcloud.deploy.build_sdn_env_list')
    @patch('builtins.open', mock_open())
    def test_create_deploy_cmd_no_ha_bm(self, mock_sdn_list, mock_prep_storage,
                                        mock_node_counts):
        mock_sdn_list.return_value = []
        mock_node_counts.return_value = (3, 2)
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ds['global_params'].__getitem__.side_effect = \
            lambda i: False if i == 'ha_enabled' else MagicMock()
        ns = {'ntp': ['ntp']}
        inv = None
        virt = False
        create_deploy_cmd(ds, ns, inv, '/tmp', virt)

    @patch('apex.overcloud.deploy._get_node_counts')
    @patch('apex.overcloud.deploy.prep_storage_env')
    @patch('apex.overcloud.deploy.build_sdn_env_list')
    def test_create_deploy_cmd_raises(self, mock_sdn_list, mock_prep_storage,
                                      mock_node_counts):
        mock_sdn_list.return_value = []
        mock_node_counts.return_value = (0, 0)
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ns = {}
        inv = None
        virt = False
        assert_raises(ApexDeployException, create_deploy_cmd,
                      ds, ns, inv, '/tmp', virt)

    @patch('apex.overcloud.deploy.virt_utils')
    @patch('apex.overcloud.deploy.shutil')
    @patch('apex.overcloud.deploy.os.path')
    @patch('builtins.open', mock_open())
    def test_prep_image(self, mock_os_path, mock_shutil, mock_virt_utils):
        ds_opts = {'dataplane': 'fdio',
                   'sdn_controller': 'opendaylight',
                   'odl_version': 'master'}
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ds['deploy_options'].__getitem__.side_effect = \
            lambda i: ds_opts.get(i, MagicMock())
        prep_image(ds, 'undercloud.qcow2', '/tmp', root_pw='test')
        mock_virt_utils.virt_customize.assert_called()

    @patch('apex.overcloud.deploy.virt_utils')
    @patch('apex.overcloud.deploy.shutil')
    @patch('apex.overcloud.deploy.os.path')
    @patch('builtins.open', mock_open())
    def test_prep_image_sdn_false(self, mock_os_path, mock_shutil,
                                  mock_virt_utils):
        ds_opts = {'dataplane': 'fdio',
                   'sdn_controller': False}
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ds['deploy_options'].__getitem__.side_effect = \
            lambda i: ds_opts.get(i, MagicMock())
        prep_image(ds, 'undercloud.qcow2', '/tmp', root_pw='test')
        mock_virt_utils.virt_customize.assert_called()

    @patch('apex.overcloud.deploy.virt_utils')
    @patch('apex.overcloud.deploy.shutil')
    @patch('apex.overcloud.deploy.os.path')
    @patch('builtins.open', mock_open())
    def test_prep_image_sdn_odl(self, mock_os_path, mock_shutil,
                                mock_virt_utils):
        ds_opts = {'dataplane': 'ovs',
                   'sdn_controller': 'opendaylight',
                   'odl_version': con.DEFAULT_ODL_VERSION,
                   'odl_vpp_netvirt': True}
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ds['deploy_options'].__getitem__.side_effect = \
            lambda i: ds_opts.get(i, MagicMock())
        ds['deploy_options'].__contains__.side_effect = \
            lambda i: True if i in ds_opts else MagicMock()
        prep_image(ds, 'undercloud.qcow2', '/tmp', root_pw='test')
        mock_virt_utils.virt_customize.assert_called()

    @patch('apex.overcloud.deploy.virt_utils')
    @patch('apex.overcloud.deploy.shutil')
    @patch('apex.overcloud.deploy.os.path')
    @patch('builtins.open', mock_open())
    def test_prep_image_sdn_odl_not_def_o_mast(self, mock_os_path,
                                               mock_shutil, mock_virt_utils):
        ds_opts = {'dataplane': 'ovs',
                   'sdn_controller': 'opendaylight',
                   'odl_version': 'uncommon'}
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ds['deploy_options'].__getitem__.side_effect = \
            lambda i: ds_opts.get(i, MagicMock())
        prep_image(ds, 'undercloud.qcow2', '/tmp', root_pw='test')
        mock_virt_utils.virt_customize.assert_called()

    @patch('apex.overcloud.deploy.virt_utils')
    @patch('apex.overcloud.deploy.shutil')
    @patch('apex.overcloud.deploy.os.path')
    @patch('builtins.open', mock_open())
    def test_prep_image_sdn_ovn(self, mock_os_path, mock_shutil,
                                mock_virt_utils):
        ds_opts = {'dataplane': 'ovs',
                   'sdn_controller': 'ovn'}
        ds = {'deploy_options': MagicMock(),
              'global_params': MagicMock()}
        ds['deploy_options'].__getitem__.side_effect = \
            lambda i: ds_opts.get(i, MagicMock())
        prep_image(ds, 'undercloud.qcow2', '/tmp', root_pw='test')
        mock_virt_utils.virt_customize.assert_called()

    @patch('apex.overcloud.deploy.os.path.isfile')
    def test_prep_image_no_image(self, mock_isfile):
        mock_isfile.return_value = False
        assert_raises(ApexDeployException, prep_image,
                      {}, 'undercloud.qcow2', '/tmp')

    @patch('apex.overcloud.deploy.rsa')
    def test_make_ssh_key(self, mock_rsa):
        make_ssh_key()
        # TODO: assert returned value

    @patch('apex.overcloud.deploy.fileinput')
    @patch('apex.overcloud.deploy.make_ssh_key')
    @patch('apex.overcloud.deploy.shutil')
    def test_prep_env(self, mock_shutil, mock_mk_ssh_key, mock_fileinput):
        mock_fileinput.input.return_value = \
            ['CloudDomain', 'replace_private_key', 'replace_public_key',
             'opendaylight::vpp_routing_node', 'ControllerExtraConfig',
             'NovaComputeExtraConfig', 'ComputeKernelArgs', 'HostCpusList',
             'ComputeExtraConfigPre', 'resource_registry',
             'NovaSchedulerDefaultFilters']
        mock_mk_ssh_key.return_value = ('priv', 'pub')
        ds = {'deploy_options':
              {'sdn_controller': 'opendaylight',
               'odl_vpp_routing_node': 'test',
               'dataplane': 'ovs_dpdk',
               'performance': {'Compute': {'vpp': {'main-core': 'test',
                                                   'corelist-workers': 'test'},
                                           'ovs': {'dpdk_cores': 'test'},
                                           'kernel': {'test': 'test'}},
                               'Controller': {'vpp': 'test'}}}}
        ns = {'domain_name': 'test.domain',
              'networks':
              {'tenant':
               {'nic_mapping': {'controller':
                                {'members': ['test']},
                                'compute':
                                {'members': ['test']}}}}}
        inv = None
        prep_env(ds, ns, inv, 'opnfv-env.yml', '/net-env.yml', '/tmp')

    @patch('apex.overcloud.deploy.fileinput')
    @patch('apex.overcloud.deploy.make_ssh_key')
    @patch('apex.overcloud.deploy.shutil')
    def test_prep_env_round_two(self, mock_shutil, mock_mk_ssh_key,
                                mock_fileinput):
        mock_fileinput.input.return_value = \
            ['NeutronVPPAgentPhysnets']
        mock_mk_ssh_key.return_value = ('priv', 'pub')
        ds = {'deploy_options':
              {'sdn_controller': False,
               'dataplane': 'fdio',
               'performance': {'Compute': {},
                               'Controller': {}}}}
        ns = {'domain_name': 'test.domain',
              'networks':
              {'tenant':
               {'nic_mapping': {'controller':
                                {'members': ['test']},
                                'compute':
                                {'members': ['test']}}}}}
        inv = None
        prep_env(ds, ns, inv, 'opnfv-env.yml', '/net-env.yml', '/tmp')

    @patch('apex.overcloud.deploy._get_node_counts')
    @patch('apex.overcloud.deploy.fileinput')
    @patch('apex.overcloud.deploy.make_ssh_key')
    @patch('apex.overcloud.deploy.shutil')
    def test_prep_env_round_three(self, mock_shutil, mock_mk_ssh_key,
                                  mock_fileinput, mock_get_node_counts):
        mock_get_node_counts.return_value = (3, 2)
        mock_fileinput.input.return_value = \
            ['OS::TripleO::Services::NeutronDhcpAgent',
             'NeutronDhcpAgentsPerNetwork', 'ComputeServices']
        mock_mk_ssh_key.return_value = ('priv', 'pub')
        ds = {'deploy_options':
              {'sdn_controller': 'opendaylight',
               'dataplane': 'fdio',
               'dvr': True}}
        ns = {'domain_name': 'test.domain',
              'networks':
              {'tenant':
               {'nic_mapping': {'controller':
                                {'members': ['test']},
                                'compute':
                                {'members': ['test']}}}}}
        inv = None
        prep_env(ds, ns, inv, 'opnfv-env.yml', '/net-env.yml', '/tmp')

    def test_generate_ceph_key(self):
        assert_equal(len(generate_ceph_key()), 40)

    @patch('apex.overcloud.deploy.generate_ceph_key')
    @patch('apex.overcloud.deploy.fileinput')
    @patch('apex.overcloud.deploy.os.path.isfile')
    @patch('builtins.open', mock_open())
    def test_prep_storage_env(self, mock_isfile, mock_fileinput,
                              mock_ceph_key):
        mock_fileinput.input.return_value = \
            ['CephClusterFSID', 'CephMonKey', 'CephAdminKey', 'random_key']
        ds = {'deploy_options': MagicMock()}
        ds['deploy_options'].__getitem__.side_effect = \
            lambda i: '/dev/sdx' if i == 'ceph_device' else MagicMock()
        ds['deploy_options'].__contains__.side_effect = \
            lambda i: True if i == 'ceph_device' else MagicMock()
        prep_storage_env(ds, '/tmp')

    @patch('apex.overcloud.deploy.os.path.isfile')
    @patch('builtins.open', mock_open())
    def test_prep_storage_env_raises(self, mock_isfile):
        mock_isfile.return_value = False
        ds = {'deploy_options': MagicMock()}
        assert_raises(ApexDeployException, prep_storage_env, ds, '/tmp')

    def test_external_network_cmds(self):
        cidr = MagicMock()
        cidr.version = 6
        ns_dict = {'networks':
                   {'external': [{'floating_ip_range': (0, 1),
                                  'nic_mapping':
                                  {'compute': {'vlan': 'native'}},
                                  'gateway': 'gw',
                                  'cidr': cidr}]}}
        ns = MagicMock()
        ns.enabled_network_list = ['external']
        ns.__getitem__.side_effect = lambda i: ns_dict.get(i, MagicMock())
        external_network_cmds(ns)

    def test_external_network_cmds_no_ext(self):
        cidr = MagicMock()
        cidr.version = 6
        ns_dict = {'apex':
                   {'networks':
                    {'admin':
                     {'introspection_range': (0, 1),
                      'nic_mapping':
                      {'compute': {'vlan': '123'}},
                      'gateway': 'gw',
                      'cidr': cidr}}}}
        ns = MagicMock()
        ns.enabled_network_list = ['admin']
        ns.__getitem__.side_effect = lambda i: ns_dict.get(i, MagicMock())
        external_network_cmds(ns)

    @patch('apex.overcloud.deploy.parsers')
    def test_create_congress_cmds(self, mock_parsers):
        create_congress_cmds('overcloud_file')

    @patch('apex.overcloud.deploy.parsers.parse_overcloudrc')
    def test_create_congress_cmds_raises(self, mock_parsers):
        mock_parsers.return_value.__getitem__.side_effect = KeyError()
        assert_raises(KeyError, create_congress_cmds, 'overcloud_file')
