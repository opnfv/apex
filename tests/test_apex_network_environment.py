##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import ipaddress

from apex.common.constants import (
        PUBLIC_NETWORK,
        PRIVATE_NETWORK,
        STORAGE_NETWORK,
        API_NETWORK)
from apex.network_settings import NetworkSettings
from apex.network_environment import (
        NetworkEnvironment,
        NetworkEnvException,
        EXTERNAL_RESOURCES,
        TENANT_RESOURCES,
        STORAGE_RESOURCES,
        API_RESOURCES)

from nose.tools import assert_equal
from nose.tools import assert_raises
from nose.tools import assert_is_instance
from nose.tools import assert_not_equal


class TestNetworkEnvironment(object):
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
        assert_raises(NetworkEnvException, NetworkEnvironment,
                      None, '../build/network-environment.yaml')

    def test_netenv_settings_public_network(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        # test vlans
        ns[PUBLIC_NETWORK]['vlan'] = 100
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        assert_equal(ne['parameter_defaults']['NeutronExternalNetworkBridge'],
                     '""')
        assert_equal(ne['parameter_defaults']['ExternalNetworkVlanID'], 100)

        # Test IPv6
        ns[PUBLIC_NETWORK]['cidr'] = ipaddress.ip_network('::1/128')
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        regstr = ne['resource_registry'][next(iter(EXTERNAL_RESOURCES.keys()))]
        assert_equal(regstr.split('/')[-1], 'external_v6.yaml')

    def test_netenv_settings_private_network(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        # test vlans
        ns[PRIVATE_NETWORK]['vlan'] = 100
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        assert_equal(ne['parameter_defaults']['TenantNetworkVlanID'], 100)

        # Test IPv6
        ns[PRIVATE_NETWORK]['cidr'] = ipaddress.ip_network('::1/128')
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        regstr = ne['resource_registry'][next(iter(TENANT_RESOURCES.keys()))]
        assert_equal(regstr.split('/')[-1], 'tenant_v6.yaml')

        # Test removing PRIVATE_NETWORK
        ns.enabled_network_list.remove(PRIVATE_NETWORK)
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        regstr = ne['resource_registry'][next(iter(TENANT_RESOURCES.keys()))]
        assert_equal(regstr.split('/')[-1], 'noop.yaml')

    def test_netenv_settings_storage_network(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        # test vlans
        ns[STORAGE_NETWORK]['vlan'] = 100
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        assert_equal(ne['parameter_defaults']['StorageNetworkVlanID'], 100)

        # Test IPv6
        ns[STORAGE_NETWORK]['cidr'] = ipaddress.ip_network('::1/128')
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        regstr = ne['resource_registry'][next(iter(STORAGE_RESOURCES.keys()))]
        assert_equal(regstr.split('/')[-1], 'storage_v6.yaml')

        # Test removing STORAGE_NETWORK
        ns.enabled_network_list.remove(STORAGE_NETWORK)
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        regstr = ne['resource_registry'][next(iter(STORAGE_RESOURCES.keys()))]
        assert_equal(regstr.split('/')[-1], 'noop.yaml')

    def test_netenv_settings_api_network(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        # test vlans
        ns.enabled_network_list.append(API_NETWORK)
        ns[API_NETWORK] = {'vlan': 100,
                           'cidr': ipaddress.ip_network('10.10.10.0/24'),
                           'usable_ip_range': '10.10.10.10,10.10.10.100'}
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        assert_equal(ne['parameter_defaults']['InternalApiNetworkVlanID'], 100)

        # Test IPv6
        ns[API_NETWORK]['cidr'] = ipaddress.ip_network('::1/128')
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        regstr = ne['resource_registry'][next(iter(API_RESOURCES.keys()))]
        assert_equal(regstr.split('/')[-1], 'internal_api_v6.yaml')

        # Test removing API_NETWORK
        ns.enabled_network_list.remove(API_NETWORK)
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        regstr = ne['resource_registry'][next(iter(API_RESOURCES.keys()))]
        assert_equal(regstr.split('/')[-1], 'noop.yaml')

    def test_numa_configs(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml',
                                compute_pre_config=True,
                                controller_pre_config=True)
        assert_is_instance(ne, dict)
        assert_not_equal(ne, {})

    def test_exception(self):
        e = NetworkEnvException("test")
        print(e)
        assert_is_instance(e, NetworkEnvException)
