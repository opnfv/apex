##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
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
from apex.settings.network_settings import NetworkSettingsException
from apex.tests.constants import TEST_CONFIG_DIR

files_dir = os.path.join(TEST_CONFIG_DIR, 'network')


class TestNetworkSettings:
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

    def test_init(self):
        assert_is_instance(
            NetworkSettings(os.path.join(files_dir, 'network_settings.yaml')),
            NetworkSettings)

    def test_init_vlans(self):
        assert_is_instance(
            NetworkSettings(os.path.join(files_dir,
                                         'network_settings_vlans.yaml')),
            NetworkSettings)

# TODO, v6 test is stuck
    # def test_init_v6(self):
    #     assert_is_instance(
    #         NetworkSettings(files_dir+'network_settings_v6.yaml', True),
    #         NetworkSettings)

    def test_init_admin_disabled_or_missing(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        # remove admin, apex section will re-add it
        ns['networks'].pop('admin', None)
        assert_raises(NetworkSettingsException, NetworkSettings, ns)
        # remove admin and apex
        ns.pop('apex', None)
        ns['networks'].pop('admin', None)
        assert_raises(NetworkSettingsException, NetworkSettings, ns)

    def test_init_collapse_storage(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        # remove storage
        ns['networks'].pop('storage', None)
        assert_is_instance(NetworkSettings(ns), NetworkSettings)

    def test_init_missing_dns_domain(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        # remove storage
        ns.pop('dns-domain', None)
        assert_is_instance(NetworkSettings(ns), NetworkSettings)

    def test_get_network_settings(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        assert_is_instance(ns, NetworkSettings)
        for role in ['controller', 'compute']:
            nic_index = 0
            print(ns.nics)
            for network in ns.enabled_network_list:
                nic = 'eth' + str(nic_index)
                assert_equal(ns.nics[role][network], nic)
                nic_index += 1

    def test_get_enabled_networks(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        assert_is_instance(ns.enabled_network_list, list)

    def test_invalid_nic_members(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        storage_net_nicmap = ns['networks'][STORAGE_NETWORK]['nic_mapping']
        # set duplicate nic
        storage_net_nicmap['controller']['members'][0] = 'eth0'
        assert_raises(NetworkSettingsException, NetworkSettings, ns)
        # remove nic members
        storage_net_nicmap['controller']['members'] = []
        assert_raises(NetworkSettingsException, NetworkSettings, ns)

    def test_missing_vlan(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        storage_net_nicmap = ns['networks'][STORAGE_NETWORK]['nic_mapping']
        # remove vlan from storage net
        storage_net_nicmap['compute'].pop('vlan', None)
        assert_is_instance(NetworkSettings(ns), NetworkSettings)
        for role in ('compute', 'controller'):
            assert_equal(ns['networks'][ADMIN_NETWORK]['nic_mapping'][
                         role]['vlan'], 'native')

# TODO
# need to manipulate interfaces some how
# maybe for ip_utils to return something to pass this
#    def test_admin_auto_detect(self):
#        ns = NetworkSettings(files_dir+'network_settings.yaml')
#        # remove cidr to force autodetection
#        ns['networks'][ADMIN_NETWORK].pop('cidr', None)
#        assert_is_instance(NetworkSettings(ns), NetworkSettings)

    def test_admin_fail_auto_detect(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        # remove cidr and installer_vm to fail autodetect
        ns['networks'][ADMIN_NETWORK].pop('cidr', None)
        ns['networks'][ADMIN_NETWORK].pop('installer_vm', None)
        assert_raises(NetworkSettingsException, NetworkSettings, ns)

    def test_exception(self):
        e = NetworkSettingsException("test")
        print(e)
        assert_is_instance(e, NetworkSettingsException)

    def test_config_ip(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        # set the provisioner ip to None to force _gen_ip to generate one
        ns['networks'][ADMIN_NETWORK]['installer_vm']['ip'] = None
        ns['networks'][EXTERNAL_NETWORK][0]['installer_vm']['ip'] = None
        # Now rebuild network settings object and check for repopulated values
        ns = NetworkSettings(ns)
        assert_equal(ns['networks'][ADMIN_NETWORK]['installer_vm']['ip'],
                     '192.0.2.1')
        assert_equal(ns['networks'][EXTERNAL_NETWORK][0]['installer_vm']['ip'],
                     '192.168.37.1')

    def test_config_gateway(self):
        ns = NetworkSettings(os.path.join(files_dir, 'network_settings.yaml'))
        # set the gateway ip to None to force _config_gateway to generate one
        ns['networks'][EXTERNAL_NETWORK][0]['gateway'] = None
        # Now rebuild network settings object and check for a repopulated value
        ns = NetworkSettings(ns)
        assert_equal(ns['networks'][EXTERNAL_NETWORK][0]['gateway'],
                     '192.168.37.1')
