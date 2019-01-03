##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os

from copy import copy

from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_not_equal,
    assert_raises)

from apex.common.constants import (
    EXTERNAL_NETWORK,
    TENANT_NETWORK,
    STORAGE_NETWORK,
    API_NETWORK,
    NET_ENV_FILE)
from apex import NetworkEnvironment
from apex.network.network_environment import NetworkEnvException
from apex import NetworkSettings
from apex.tests.constants import TEST_CONFIG_DIR
from apex.tests.constants import TEST_BUILD_DIR


class TestNetworkEnvironment:
    @classmethod
    def setup_class(cls):
        """This method is run once for each class before any tests are run"""
        cls.ns = NetworkSettings(
            os.path.join(TEST_CONFIG_DIR, 'network/network_settings.yaml'))
        cls.ns_vlans = NetworkSettings(
            os.path.join(TEST_CONFIG_DIR,
                         'network/network_settings_vlans.yaml'))
        cls.ns_ipv6 = NetworkSettings(
            os.path.join(TEST_CONFIG_DIR, 'network/network_settings_v6.yaml'))

    @classmethod
    def teardown_class(klass):
        """This method is run once for each class _after_ all tests are run"""

    def setup(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_init(self):
        assert_raises(NetworkEnvException, NetworkEnvironment,
                      None, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))

    def test_netenv_settings_external_network_vlans(self):
        # test vlans
        ne = NetworkEnvironment(self.ns_vlans,
                                os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert_equal(ne['parameter_defaults']['NeutronExternalNetworkBridge'],
                     '""')
        assert_equal(ne['parameter_defaults']['ExternalNetworkVlanID'], 501)

    def test_netenv_settings_external_network_ipv6(self):
        # Test IPv6
        ne = NetworkEnvironment(self.ns_ipv6,
                                os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        regstr = ne['resource_registry']['OS::TripleO::Network::External']
        assert_equal(regstr.split('/')[-1], 'external_v6.yaml')

    def test_netenv_settings_external_network_removed(self):
        ns = copy(self.ns)
        # Test removing EXTERNAL_NETWORK
        ns.enabled_network_list.remove(EXTERNAL_NETWORK)
        ne = NetworkEnvironment(ns, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert 'OS::TripleO::Network::External' not in ne['resource_registry']

    def test_netenv_settings_tenant_network_vlans(self):
        # test vlans
        ne = NetworkEnvironment(self.ns_vlans,
                                os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert_equal(ne['parameter_defaults']['TenantNetworkVlanID'], 401)

# Apex is does not support v6 tenant networks
# Though there is code that would fire if a
# v6 cidr was passed in, just uncomment this to
# cover that code
#    def test_netenv_settings_tenant_network_v6(self):
#        # Test IPv6
#        ne = NetworkEnvironment(self.ns_ipv6,
#                                '../build/network-environment.yaml')
#        regstr = ne['resource_registry'][next(iter(TENANT_RESOURCES.keys()))]
#        assert_equal(regstr.split('/')[-1], 'tenant_v6.yaml')

    def test_netenv_settings_tenant_network_removed(self):
        ns = copy(self.ns)
        # Test removing TENANT_NETWORK
        ns.enabled_network_list.remove(TENANT_NETWORK)
        ne = NetworkEnvironment(ns, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert 'OS::TripleO::Network::Tenant' not in ne['resource_registry']

    def test_netenv_settings_storage_network_vlans(self):
        # test vlans
        ne = NetworkEnvironment(self.ns_vlans,
                                os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert_equal(ne['parameter_defaults']['StorageNetworkVlanID'], 201)

    def test_netenv_settings_storage_network_v6(self):
        # Test IPv6
        ne = NetworkEnvironment(self.ns_ipv6,
                                os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        regstr = ne['resource_registry']['OS::TripleO::Network::Storage']
        assert_equal(regstr.split('/')[-1], 'storage_v6.yaml')

    def test_netenv_settings_storage_network_removed(self):
        ns = copy(self.ns)
        # Test removing STORAGE_NETWORK
        ns.enabled_network_list.remove(STORAGE_NETWORK)
        ne = NetworkEnvironment(ns, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert 'OS::TripleO::Network::Storage' not in ne['resource_registry']

    def test_netenv_settings_api_network_v4(self):
        ns = copy(self.ns_vlans)
        ns['networks'][API_NETWORK]['enabled'] = True
        ns['networks'][API_NETWORK]['cidr'] = '10.11.12.0/24'
        ns = NetworkSettings(ns)
        # test vlans
        ne = NetworkEnvironment(ns, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert_equal(ne['parameter_defaults']['InternalApiNetworkVlanID'], 101)

    def test_netenv_settings_api_network_vlans(self):
        ns = copy(self.ns_vlans)
        ns['networks'][API_NETWORK]['enabled'] = True
        ns = NetworkSettings(ns)
        # test vlans
        ne = NetworkEnvironment(ns, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert_equal(ne['parameter_defaults']['InternalApiNetworkVlanID'], 101)

    def test_netenv_settings_api_network_v6(self):
        # Test IPv6
        ne = NetworkEnvironment(self.ns_ipv6,
                                os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        regstr = ne['resource_registry']['OS::TripleO::Network::InternalApi']
        assert_equal(regstr.split('/')[-1], 'internal_api_v6.yaml')

    def test_netenv_settings_api_network_removed(self):
        ns = copy(self.ns)
        # API_NETWORK is not in the default network settings file
        ne = NetworkEnvironment(ns, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        assert 'OS::TripleO::Network::InternalApi' not in ne[
            'resource_registry']

    def test_numa_configs(self):
        ne = NetworkEnvironment(self.ns,
                                os.path.join(TEST_BUILD_DIR, NET_ENV_FILE),
                                compute_pre_config=True,
                                controller_pre_config=True)
        assert_is_instance(ne, dict)
        assert_not_equal(ne, {})

    def test_exception(self):
        e = NetworkEnvException("test")
        print(e)
        assert_is_instance(e, NetworkEnvException)

    def test_service_netmap(self):
        ns = copy(self.ns)
        ns.enabled_network_list = ['admin']
        ne = NetworkEnvironment(ns, os.path.join(TEST_BUILD_DIR, NET_ENV_FILE))
        for network in ne['parameter_defaults']['ServiceNetMap'].values():
            assert_equal(network, 'ctlplane')
