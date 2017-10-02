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

from apex.overcloud.config import create_nic_template
from apex.common.exceptions import ApexDeployException

from nose.tools import (
    assert_regexp_matches,
    assert_raises,
    assert_equal)


class TestOvercloudConfig(unittest.TestCase):
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

    def test_create_nic_template_invalid_role(self):
        assert_raises(ApexDeployException, create_nic_template,
                      None, None, None, None, None)

    @patch('apex.overcloud.config.Environment')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_create_nic_template_ctl_fdio(self, mock_env):
        network_settings = MagicMock()
        deploy_settings = MagicMock()
        deploy_settings.get.return_value = {'dataplane': 'fdio',
                                            'sdn_controller': 'opendaylight'}

        create_nic_template(network_settings, deploy_settings,
                            'controller', 'template_dir', 'target_dir')

    @patch('apex.overcloud.config.Environment')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_create_nic_template_ctl_ovs_dpdk(self, mock_env):
        network_settings = MagicMock()
        deploy_settings = MagicMock()
        deploy_settings.get.return_value = {'dataplane': 'ovs_dpdk',
                                            'sdn_controller': 'opendaylight',
                                            'sfc': True}
        create_nic_template(network_settings, deploy_settings,
                            'controller', 'template_dir', 'target_dir')

    @patch('apex.overcloud.config.Environment')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_create_nic_template_comp_fdio(self, mock_env):
        network_settings = MagicMock()
        deploy_settings = MagicMock()
        deploy_settings.get.return_value = {'performance':
                                            {'Compute':
                                             {'vpp':
                                              {'uio-driver': 'test',
                                               'interface-options': 'test'}}},
                                            'dvr': True,
                                            'dataplane': 'fdio',
                                            'sdn_controller': 'opendaylight'}
        create_nic_template(network_settings, deploy_settings,
                            'compute', 'template_dir', 'target_dir')
