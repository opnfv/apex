##############################################################################
# Copyright (c) 2017 Tim Rozet (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import unittest

from apex.builders import common_builder as c_builder
from apex.builders import exceptions
from apex.common import constants as con
from mock import patch
from mock import mock_open
from mock import MagicMock

DOCKER_YAML = {
    'resource_registry': {
        'OS::TripleO::Services::NovaApi': '../docker/services/nova-api.yaml',
        'OS::TripleO::Services::NovaConductor':
            '../docker/services/nova-conductor.yaml'
    }
}

a_mock_open = mock_open(read_data=None)


class TestCommonBuilder(unittest.TestCase):
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

    def test_project_to_path(self):
        project = 'openstack/tripleo-heat-templates'
        path = '/usr/share/openstack-tripleo-heat-templates'
        self.assertEquals(c_builder.project_to_path(project), path)
        project = 'openstack/puppet-tripleo'
        path = '/etc/puppet/modules/tripleo'
        self.assertEquals(c_builder.project_to_path(project), path)
        project = 'openstack/nova'
        path = '/usr/lib/python2.7/site-packages/'
        self.assertEquals(c_builder.project_to_path(project), path)

    def test_is_patch_promoted(self):
        dummy_change = {'submitted': '2017-06-05 20:23:09.000000000',
                        'status': 'MERGED'}
        self.assertTrue(c_builder.is_patch_promoted(dummy_change,
                                                    'master'))

    def test_is_patch_promoted_docker(self):
        dummy_change = {'submitted': '2017-06-05 20:23:09.000000000',
                        'status': 'MERGED'}
        dummy_image = 'centos-binary-opendaylight'
        self.assertTrue(c_builder.is_patch_promoted(dummy_change,
                                                    'master',
                                                    docker_image=dummy_image))

    def test_patch_not_promoted(self):
        dummy_change = {'submitted': '2900-06-05 20:23:09.000000000',
                        'status': 'MERGED'}
        self.assertFalse(c_builder.is_patch_promoted(dummy_change,
                                                     'master'))

    def test_patch_not_promoted_docker(self):
        dummy_change = {'submitted': '2900-06-05 20:23:09.000000000',
                        'status': 'MERGED'}
        dummy_image = 'centos-binary-opendaylight'
        self.assertFalse(c_builder.is_patch_promoted(dummy_change,
                                                     'master',
                                                     docker_image=dummy_image))

    def test_patch_not_promoted_and_not_merged(self):
        dummy_change = {'submitted': '2900-06-05 20:23:09.000000000',
                        'status': 'BLAH'}
        self.assertFalse(c_builder.is_patch_promoted(dummy_change,
                                                     'master'))

    @patch('builtins.open', mock_open())
    @patch('apex.builders.common_builder.is_patch_promoted')
    @patch('apex.build_utils.get_change')
    @patch('apex.build_utils.get_patch')
    @patch('apex.virtual.utils.virt_customize')
    def test_add_upstream_patches(self, mock_customize, mock_get_patch,
                                  mock_get_change, mock_is_patch_promoted):
        mock_get_patch.return_value = None
        change_id = 'I301370fbf47a71291614dd60e4c64adc7b5ebb42'
        patches = [{
            'change-id': change_id,
            'project': 'openstack/tripleo-heat-templates'
        }]
        c_builder.add_upstream_patches(patches, 'dummy.qcow2', '/dummytmp/')
        assert mock_customize.not_called
        project_path = '/usr/share/openstack-tripleo-heat-templates'
        patch_file = "{}.patch".format(change_id)
        patch_file_path = "/dummytmp/{}".format(patch_file)
        test_virt_ops = [
            {con.VIRT_INSTALL: 'patch'},
            {con.VIRT_UPLOAD: "{}:{}".format(patch_file_path,
                                             project_path)},
            {con.VIRT_RUN_CMD: "cd {} && patch -p1 < {}".format(
                project_path, patch_file)}]
        mock_get_patch.return_value = 'some random diff'
        mock_is_patch_promoted.return_value = False
        c_builder.add_upstream_patches(patches, 'dummy.qcow2', '/dummytmp/')
        mock_customize.assert_called_once_with(test_virt_ops, 'dummy.qcow2')

    @patch('builtins.open', mock_open())
    @patch('apex.builders.common_builder.is_patch_promoted')
    @patch('apex.build_utils.get_change')
    @patch('apex.build_utils.get_patch')
    @patch('apex.virtual.utils.virt_customize')
    def test_add_upstream_patches_docker_puppet(
            self, mock_customize, mock_get_patch, mock_get_change,
            mock_is_patch_promoted):
        change_id = 'I301370fbf47a71291614dd60e4c64adc7b5ebb42'
        patches = [{
            'change-id': change_id,
            'project': 'openstack/puppet-tripleo'
        }]
        project_path = '/etc/puppet/modules/tripleo'
        patch_file = "{}.patch".format(change_id)
        patch_file_path = "/dummytmp/{}".format(patch_file)
        test_virt_ops = [
            {con.VIRT_INSTALL: 'patch'},
            {con.VIRT_UPLOAD: "{}:{}".format(patch_file_path,
                                             project_path)},
            {con.VIRT_RUN_CMD: "cd {} && patch -p1 < {}".format(
                project_path, patch_file)}]
        mock_get_patch.return_value = 'some random diff'
        mock_is_patch_promoted.return_value = False
        c_builder.add_upstream_patches(patches, 'dummy.qcow2', '/dummytmp/',
                                       uc_ip='192.0.2.1',
                                       docker_tag='latest')
        mock_customize.assert_called_once_with(test_virt_ops, 'dummy.qcow2')

    @patch('builtins.open', mock_open())
    @patch('apex.builders.common_builder.is_patch_promoted')
    @patch('apex.build_utils.get_change')
    @patch('apex.builders.common_builder.project_to_docker_image')
    @patch('apex.builders.overcloud_builder.build_dockerfile')
    @patch('apex.build_utils.get_patch')
    @patch('apex.virtual.utils.virt_customize')
    def test_add_upstream_patches_docker_python(
            self, mock_customize, mock_get_patch, mock_build_docker_file,
            mock_project2docker, ock_get_change, mock_is_patch_promoted):
        mock_project2docker.return_value = ['NovaApi']
        change_id = 'I301370fbf47a71291614dd60e4c64adc7b5ebb42'
        patches = [{
            'change-id': change_id,
            'project': 'openstack/nova'
        }]
        mock_get_patch.return_value = 'some random diff'
        mock_is_patch_promoted.return_value = False
        services = c_builder.add_upstream_patches(patches, 'dummy.qcow2',
                                                  '/dummytmp/',
                                                  uc_ip='192.0.2.1',
                                                  docker_tag='latest')
        assert mock_customize.not_called
        assert mock_build_docker_file.called
        self.assertSetEqual(services, {'NovaApi'})

    @patch('builtins.open', mock_open())
    @patch('apex.builders.common_builder.is_patch_promoted')
    @patch('apex.build_utils.get_change')
    @patch('apex.builders.common_builder.project_to_docker_image')
    @patch('apex.builders.overcloud_builder.build_dockerfile')
    @patch('apex.build_utils.get_patch')
    @patch('apex.virtual.utils.virt_customize')
    def test_not_add_upstream_patches_docker_python(
            self, mock_customize, mock_get_patch, mock_build_docker_file,
            mock_project2docker, ock_get_change, mock_is_patch_promoted):
        # Test that the calls are not made when the patch is already merged and
        # promoted
        mock_project2docker.return_value = ['NovaApi']
        change_id = 'I301370fbf47a71291614dd60e4c64adc7b5ebb42'
        patches = [{
            'change-id': change_id,
            'project': 'openstack/nova'
        }]
        mock_get_patch.return_value = 'some random diff'
        mock_is_patch_promoted.return_value = True
        services = c_builder.add_upstream_patches(patches, 'dummy.qcow2',
                                                  '/dummytmp/',
                                                  uc_ip='192.0.2.1',
                                                  docker_tag='latest')
        assert mock_customize.not_called
        assert mock_build_docker_file.not_called
        assert len(services) == 0

    @patch('builtins.open', mock_open())
    @patch('apex.builders.common_builder.is_patch_promoted')
    @patch('apex.build_utils.get_change')
    @patch('apex.build_utils.get_patch')
    @patch('apex.virtual.utils.virt_customize')
    def test_not_upstream_patches_docker_puppet(
            self, mock_customize, mock_get_patch, mock_get_change,
            mock_is_patch_promoted):
        # Test that the calls are not made when the patch is already merged and
        # promoted
        change_id = 'I301370fbf47a71291614dd60e4c64adc7b5ebb42'
        patches = [{
            'change-id': change_id,
            'project': 'openstack/puppet-tripleo'
        }]
        mock_get_patch.return_value = 'some random diff'
        mock_is_patch_promoted.return_value = True
        c_builder.add_upstream_patches(patches, 'dummy.qcow2', '/dummytmp/',
                                       uc_ip='192.0.2.1',
                                       docker_tag='latest')
        assert mock_customize.not_called

    @patch('builtins.open', mock_open())
    @patch('apex.virtual.utils.virt_customize')
    def test_add_repo(self, mock_customize):
        c_builder.add_repo('fake/url', 'dummyrepo', 'dummy.qcow2',
                           '/dummytmp/')
        repo_file_path = '/dummytmp/dummyrepo.repo'
        test_virt_ops = [
            {con.VIRT_UPLOAD: "{}:/etc/yum.repos.d/".format(repo_file_path)}
        ]
        mock_customize.assert_called_once_with(test_virt_ops, 'dummy.qcow2')

    @patch('builtins.open', mock_open())
    @patch('git.Repo.clone_from')
    def test_create_git_archive(self, mock_git):
        mock_git.return_value = MagicMock()
        self.assertEqual(c_builder.create_git_archive('fake/url', 'dummyrepo',
                                                      '/dummytmp/'),
                         '/dummytmp/dummyrepo.tar')

    def test_project_to_docker_image(self):
        found_services = c_builder.project_to_docker_image(project='nova')
        assert 'nova-api' in found_services

    @patch('apex.common.utils.open_webpage')
    def test_project_to_docker_image_bad_web_content(
            self, mock_open_web):
        mock_open_web.return_value = b'{"blah": "blah"}'
        self.assertRaises(exceptions.ApexCommonBuilderException,
                          c_builder.project_to_docker_image,
                          'nova')

    @patch('apex.builders.common_builder.yaml')
    @patch('apex.overcloud.deploy.os.path.isfile')
    @patch('builtins.open', a_mock_open, create=True)
    def test_prepare_container_images(self, mock_is_file, mock_yaml):
        mock_yaml.safe_load.return_value = {
            'parameter_defaults': {
                'ContainerImagePrepare': [
                    {'set':
                        {'namespace': 'blah',
                         'neutron_driver': 'null',
                         }
                     }
                ]
            }
        }
        expected_output = {
            'parameter_defaults': {
                'ContainerImagePrepare': [
                    {'set':
                        {'namespace': 'docker.io/tripleoqueens',
                         'neutron_driver': 'opendaylight',
                         }
                     }
                ]
            }
        }

        c_builder.prepare_container_images('dummy.yaml', 'queens',
                                           'opendaylight')
        mock_yaml.safe_dump.assert_called_with(
            expected_output,
            a_mock_open.return_value,
            default_flow_style=False)
