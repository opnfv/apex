##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

from apex.common.constants import (
    STORAGE_NETWORK,
    ADMIN_NETWORK,
)

from apex.network_settings import (
    NetworkSettings,
    NetworkSettingsException,
)

from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_raises
)

files_dir = '../config/network/'


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
        assert_is_instance(
            NetworkSettings(files_dir+'network_settings.yaml', True),
            NetworkSettings)

    def test_init_vlans(self):
        assert_is_instance(
            NetworkSettings(files_dir+'network_settings_vlans.yaml', True),
            NetworkSettings)

# TODO, v6 test is stuck
    # def test_init_v6(self):
    #     assert_is_instance(
    #         NetworkSettings(files_dir+'network_settings_v6.yaml', True),
    #         NetworkSettings)

    def test_init_admin_disabled_or_missing(self):
        ns = NetworkSettings(files_dir+'network_settings.yaml', True)
        # remove admin, apex section will re-add it
        ns['networks'].pop('admin', None)
        assert_raises(NetworkSettingsException, NetworkSettings, ns, True)
        # remove admin and apex
        ns.pop('apex', None)
        ns['networks'].pop('admin', None)
        assert_raises(NetworkSettingsException, NetworkSettings, ns, True)

    def test_init_collapse_storage(self):
        ns = NetworkSettings(files_dir+'network_settings.yaml', True)
        # remove storage
        ns['networks'].pop('storage', None)
        assert_is_instance(NetworkSettings(ns, True), NetworkSettings)

    def test_init_missing_dns_domain(self):
        ns = NetworkSettings(files_dir+'network_settings.yaml', True)
        # remove storage
        ns.pop('dns-domain', None)
        assert_is_instance(NetworkSettings(ns, True), NetworkSettings)

    def test_dump_bash(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_equal(ns.dump_bash(), None)
        assert_equal(ns.dump_bash(path='/dev/null'), None)

    def test_get_network_settings(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_is_instance(ns, NetworkSettings)
        for role in ['controller', 'compute']:
            nic_index = 1
            print(ns.nics)
            for network in ns.enabled_network_list:
                nic = 'nic' + str(nic_index)
                assert_equal(ns.nics[role][network], nic)
                nic_index += 1

    def test_get_enabled_networks(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_is_instance(ns.enabled_network_list, list)

    def test_invalid_nic_members(self):
        ns = NetworkSettings(files_dir+'network_settings.yaml', True)
        storage_net_nicmap = ns['networks'][STORAGE_NETWORK]['nic_mapping']
        # set duplicate nic
        storage_net_nicmap['compute']['members'][0] = 'nic1'
        assert_raises(NetworkSettingsException, NetworkSettings, ns, True)
        # remove nic members
        storage_net_nicmap['compute']['members'] = []
        assert_raises(NetworkSettingsException, NetworkSettings, ns, True)

    def test_missing_vlan(self):
        ns = NetworkSettings(files_dir+'network_settings.yaml', True)
        storage_net_nicmap = ns['networks'][STORAGE_NETWORK]['nic_mapping']
        # remove vlan from storage net
        storage_net_nicmap['compute'].pop('vlan', None)
        assert_is_instance(NetworkSettings(ns, True), NetworkSettings)

# TODO
# need to manipulate interfaces some how
# maybe for ip_utils to return something to pass this
#    def test_admin_auto_detect(self):
#        ns = NetworkSettings(files_dir+'network_settings.yaml', True)
#        # remove cidr to force autodetection
#        ns['networks'][ADMIN_NETWORK].pop('cidr', None)
#        assert_is_instance(NetworkSettings(ns, True), NetworkSettings)

    def test_admin_fail_auto_detect(self):
        ns = NetworkSettings(files_dir+'network_settings.yaml', True)
        # remove cidr and installer_vm to fail autodetect
        ns['networks'][ADMIN_NETWORK].pop('cidr', None)
        ns['networks'][ADMIN_NETWORK].pop('installer_vm', None)
        assert_raises(NetworkSettingsException, NetworkSettings, ns, True)

    def test_exception(self):
        e = NetworkSettingsException("test")
        print(e)
        assert_is_instance(e, NetworkSettingsException)
