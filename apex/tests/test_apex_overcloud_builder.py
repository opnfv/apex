##############################################################################
# Copyright (c) 2017 Tim Rozet (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import unittest

from apex.builders import overcloud_builder as oc_builder
from apex.common import constants as con
from mock import patch, mock_open

a_mock_open = mock_open(read_data=None)


class TestOvercloudBuilder(unittest.TestCase):
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

    @patch('apex.builders.common_builder.create_git_archive')
    @patch('apex.builders.common_builder.add_repo')
    @patch('apex.virtual.utils.virt_customize')
    def test_inject_opendaylight(self, mock_customize, mock_add_repo,
                                 mock_git_archive):
        mock_git_archive.return_value = '/dummytmp/puppet-opendaylight.tar'
        archive = '/dummytmp/puppet-opendaylight.tar'
        test_virt_ops = [
            {con.VIRT_UPLOAD: "{}:/etc/puppet/modules/".format(archive)},
            {con.VIRT_RUN_CMD: 'rm -rf /etc/puppet/modules/opendaylight'},
            {con.VIRT_RUN_CMD: "cd /etc/puppet/modules/ && tar xvf "
                               "puppet-opendaylight.tar"},
            {con.VIRT_INSTALL: 'opendaylight'}
        ]
        oc_builder.inject_opendaylight(con.DEFAULT_ODL_VERSION, 'dummy.qcow2',
                                       '/dummytmp/', uc_ip='192.0.2.2',
                                       os_version=con.DEFAULT_OS_VERSION)
        assert mock_git_archive.called
        assert mock_add_repo.called
        mock_customize.assert_called_once_with(test_virt_ops, 'dummy.qcow2')

    @patch('apex.builders.overcloud_builder.build_dockerfile')
    @patch('apex.builders.common_builder.create_git_archive')
    @patch('apex.builders.common_builder.add_repo')
    @patch('apex.virtual.utils.virt_customize')
    def test_inject_opendaylight_docker(self, mock_customize, mock_add_repo,
                                        mock_git_archive, mock_build_docker):
        mock_git_archive.return_value = '/dummytmp/puppet-opendaylight.tar'
        archive = '/dummytmp/puppet-opendaylight.tar'
        test_virt_ops = [
            {con.VIRT_UPLOAD: "{}:/etc/puppet/modules/".format(archive)},
            {con.VIRT_RUN_CMD: 'rm -rf /etc/puppet/modules/opendaylight'},
            {con.VIRT_RUN_CMD: "cd /etc/puppet/modules/ && tar xvf "
                               "puppet-opendaylight.tar"},
        ]
        oc_builder.inject_opendaylight('oxygen', 'dummy.qcow2',
                                       '/dummytmp/', uc_ip='192.0.2.2',
                                       os_version=con.DEFAULT_OS_VERSION,
                                       docker_tag='latest')
        odl_url = "https://nexus.opendaylight.org/content/repositories" \
                  "/opendaylight-oxygen-epel-7-x86_64-devel/"
        docker_cmds = [
            "RUN yum remove opendaylight -y",
            "RUN echo $'[opendaylight]\\n\\",
            "baseurl={}\\n\\".format(odl_url),
            "gpgcheck=0\\n\\",
            "enabled=1' > /etc/yum.repos.d/opendaylight.repo",
            "RUN yum -y install opendaylight"
        ]
        src_img_uri = "192.0.2.1:8787/nova-api/centos-binary-master:latest"
        assert mock_git_archive.called
        assert mock_add_repo.called
        assert mock_build_docker.called_once_with(
            'opendaylight', '/dummytmp', docker_cmds, src_img_uri
        )
        mock_customize.assert_called_once_with(test_virt_ops, 'dummy.qcow2')

    @patch('builtins.open', a_mock_open)
    @patch('os.makedirs')
    @patch('os.path.isfile')
    @patch('os.path.isdir')
    def test_build_dockerfile(self, mock_isdir, mock_isfile, mock_makedirs):
        src_img_uri = "192.0.2.1:8787/nova-api/centos-binary-master:latest"
        oc_builder.build_dockerfile('nova-api', '/tmpdummy/', ['RUN dummy'],
                                    src_img_uri)
        a_mock_open.assert_called_with(
            '/tmpdummy/containers/nova-api/Dockerfile', 'a+')
        a_mock_open().write.assert_called_once_with('RUN dummy')

    @patch('tarfile.open')
    @patch('os.path.isdir')
    def test_archive_docker_patches(self, mock_isdir, mock_tarfile):
        oc_builder.archive_docker_patches('/tmpdummy/')
        assert mock_tarfile.assert_called
