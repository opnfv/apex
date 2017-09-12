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
from mock import patch


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
            {con.VIRT_INSTALL: 'opendaylight'},
            {con.VIRT_UPLOAD: "{}:/etc/puppet/modules/".format(archive)},
            {con.VIRT_RUN_CMD: "cd /etc/puppet/modules/ && tar xvf "
                               "puppet-opendaylight.tar"}
        ]
        oc_builder.inject_opendaylight(con.DEFAULT_ODL_VERSION, 'dummy.qcow2',
                                       '/dummytmp/')
        assert mock_git_archive.called
        assert mock_add_repo.called
        mock_customize.assert_called_once_with(test_virt_ops, 'dummy.qcow2')

