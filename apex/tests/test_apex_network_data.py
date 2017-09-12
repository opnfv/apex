##############################################################################
# Copyright (c) 2017 Tim Rozet (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os

from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_raises
)

from apex.common.constants import (
    EXTERNAL_NETWORK,
    STORAGE_NETWORK,
    ADMIN_NETWORK,
)
from apex import NetworkSettings
from apex.network import network_data
from apex.settings.network_settings import NetworkSettingsException
from apex.tests.constants import TEST_CONFIG_DIR

files_dir = os.path.join(TEST_CONFIG_DIR, 'network')

REQUIRED_KEYS = [
    'name',
    'vip',
    'name_lower',
    'enabled'
]


class TestNetworkData:
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

    def test_create_network_data(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        output = network_data.create_network_data(ns)
        assert_is_instance(output, list)
        assert len(output) is 4
        for net in output:
            assert_is_instance(net, dict)
            for key in REQUIRED_KEYS:
                assert key in net
                if key == 'vip' or key == 'enabled':
                    assert_is_instance(net[key], bool)
                else:
                    assert net[key] is not None

    def test_negative_create_network_data(self):
        assert_raises(network_data.NetworkDataException,
                      network_data.create_network_data, 'blah')

    def test_create_network_data_with_write(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        network_data.create_network_data(ns, '/tmp/blah_network_data.yaml')
        assert os.path.isfile('/tmp/blah_network_data.yaml')
        os.remove('/tmp/blah_network_data.yaml')
