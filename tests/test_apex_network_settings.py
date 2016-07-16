##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

from apex.network_settings import (
    NetworkSettings,
    NetworkSettingsException,
)

from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_raises
)


class TestNetworkSettings(object):
    @classmethod
    def setup_class(klass):
        """This method is run once for each class before any tests are run"""

    @classmethod
    def teardown_class(klass):
        """This method is run once for each class _after_ all tests are run"""

    def setUp(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_init(self):
        NetworkSettings('../config/network/network_settings.yaml', True)

    def test_dump_bash(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_equal(ns.dump_bash(), None)
        assert_equal(ns.dump_bash(path='/dev/null'), None)

    def test_get_network_settings(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_is_instance(ns.get_network_settings(), dict)
        for role in ['controller', 'compute']:
            nic_index = 1
            for network in ['admin_network', 'private_network',
                            'public_network', 'storage_network']:
                nic = 'nic' + str(nic_index)
                assert_equal(ns.nics[role][network], nic)
                nic_index += 1

    def test_get_network_settings_unspecified_nics(self):
        ns = NetworkSettings(
            '../tests/config/network_settings_nics_not_specified.yaml',
            True)
        assert_is_instance(ns.get_network_settings(), dict)
        for role in ['controller', 'compute']:
            nic_index = 1
            for network in ['admin_network', 'private_network',
                            'public_network', 'storage_network']:
                nic = 'nic' + str(nic_index)
                assert_equal(ns.nics[role][network], nic)
                nic_index += 1

    def test_get_enabled_networks(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_is_instance(ns.get_enabled_networks(), list)

    def test_negative_network_settings(self):
        assert_raises(NetworkSettingsException, NetworkSettings,
                      '../tests/config/network_settings_duplicate_nic.yaml',
                      True)
        assert_raises(NetworkSettingsException, NetworkSettings,
                      '../tests/config/network_settings_nic1_reserved.yaml',
                      True)
        assert_raises(NetworkSettingsException, NetworkSettings,
                      '../tests/config/network_settings_missing_required_nic'
                      '.yaml', True)
