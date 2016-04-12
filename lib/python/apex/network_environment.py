##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import yaml
import re
from .common import constants

PORTS = '/ports'
# Resources defined by <resource name>: <prefix>
EXTERNAL_RESOURCES = {'OS::TripleO::Network::External': None,
                      'OS::TripleO::Network::Ports::ExternalVipPort': PORTS,
                      'OS::TripleO::Controller::Ports::ExternalPort': PORTS,
                      'OS::TripleO::Compute::Ports::ExternalPort': PORTS}
TENANT_RESOURCES = {'OS::TripleO::Network::Tenant': None,
                    'OS::TripleO::Controller::Ports::TenantPort': PORTS,
                    'OS::TripleO::Compute::Ports::TenantPort': PORTS}
STORAGE_RESOURCES = {'OS::TripleO::Network::Storage': None,
                     'OS::TripleO::Network::Ports::StorageVipPort': PORTS,
                     'OS::TripleO::Controller::Ports::StoragePort': PORTS,
                     'OS::TripleO::Compute::Ports::StoragePort': PORTS}
API_RESOURCES = {'OS::TripleO::Network::InternalApi': None,
                 'OS::TripleO::Network::Ports::InternalApiVipPort': PORTS,
                 'OS::TripleO::Controller::Ports::InternalApiPort': PORTS,
                 'OS::TripleO::Compute::Ports::InternalApiPort': PORTS}

# A list of flags that will be set to true when IPv6 is enabled
IPV6_FLAGS = ["NovaIPv6", "MongoDbIPv6", "CorosyncIPv6", "CephIPv6",
              "RabbitIPv6", "MemcachedIPv6"]


class NetworkEnvironment:
    """
    This class creates a Network Environment to be used in TripleO Heat
    Templates.

    The class builds upon an existing network-environment file and modifies
    based on a NetworkSettings object.
    """
    def __init__(self, net_settings, filename):
        with open(filename, 'r') as net_env_fh:
            self.netenv_obj = yaml.load(net_env_fh)
            self._update_net_environment(net_settings)

    def _update_net_environment(self, settings_obj):
        """
        Updates Network Environment according to Network Settings
        :param: network settings object
        :return:  None
        """
        if not settings_obj:
            raise NetworkEnvException("Network Settings does not exist")

        net_settings = settings_obj.get_network_settings()
        enabled_networks = settings_obj.get_enabled_networks()
        param_def = 'parameter_defaults'
        reg = 'resource_registry'
        for key, prefix in TENANT_RESOURCES.items():
            if prefix is None:
                prefix = ''
            m = re.split('%s/\w+\.yaml' % prefix, self.netenv_obj[reg][key])
            if m is not None:
                tht_dir = m[0]
                break
        if not tht_dir:
            raise NetworkEnvException('Unable to parse THT Directory')

        admin_cidr = net_settings[constants.ADMIN_NETWORK]['cidr']
        admin_prefix = str(admin_cidr.prefixlen)
        self.netenv_obj[param_def]['ControlPlaneSubnetCidr'] = admin_prefix
        self.netenv_obj[param_def]['ControlPlaneDefaultRoute'] = \
            net_settings[constants.ADMIN_NETWORK]['provisioner_ip']
        public_cidr = net_settings[constants.PUBLIC_NETWORK]['cidr']
        self.netenv_obj[param_def]['ExternalNetCidr'] = str(public_cidr)
        if net_settings[constants.PUBLIC_NETWORK]['vlan'] != 'native':
            self.netenv_obj[param_def]['ExternalNetworkVlanID'] = \
                    net_settings[constants.PUBLIC_NETWORK]['vlan']
        public_range = net_settings[constants.PUBLIC_NETWORK][
                                         'usable_ip_range'].split(',')
        self.netenv_obj[param_def]['ExternalAllocationPools'] = \
            [{'start':
              public_range[0],
              'end': public_range[1]
              }]
        self.netenv_obj[param_def]['ExternalInterfaceDefaultRoute'] = \
            net_settings[constants.PUBLIC_NETWORK]['gateway']
        self.netenv_obj[param_def]['EC2MetadataIp'] = \
            net_settings[constants.ADMIN_NETWORK]['provisioner_ip']
        self.netenv_obj[param_def]['DnsServers'] = net_settings['dns_servers']

        if public_cidr.version == 6:
            postfix = '/external_v6.yaml'
        else:
            postfix = '/external.yaml'

        for key, prefix in EXTERNAL_RESOURCES.items():
            if prefix is None:
                prefix = ''
            self.netenv_obj[reg][key] = tht_dir + prefix + postfix


        if constants.PRIVATE_NETWORK in enabled_networks:
            priv_range = net_settings[constants.PRIVATE_NETWORK][
                'usable_ip_range'].split(',')
            self.netenv_obj[param_def]['TenantAllocationPools'] = \
                [{'start':
                  priv_range[0],
                  'end': priv_range[1]
                  }]
            priv_cidr = net_settings[constants.PRIVATE_NETWORK]['cidr']
            self.netenv_obj[param_def]['TenantNetCidr'] = str(priv_cidr)
            if priv_cidr.version == 6:
                postfix = '/tenant_v6.yaml'
            else:
                postfix = '/tenant.yaml'
            if net_settings[constants.PRIVATE_NETWORK]['vlan'] != 'native':
                self.netenv_obj[param_def]['TenantNetworkVlanID'] = \
                         net_settings[constants.PRIVATE_NETWORK]['vlan']
        else:
            postfix = '/noop.yaml'

        for key, prefix in TENANT_RESOURCES.items():
            if prefix is None:
                prefix = ''
            self.netenv_obj[reg][key] = tht_dir + prefix + postfix

        if constants.STORAGE_NETWORK in enabled_networks:
            storage_range = net_settings[constants.STORAGE_NETWORK][
                'usable_ip_range'].split(',')
            self.netenv_obj[param_def]['StorageAllocationPools'] = \
                [{'start':
                  storage_range[0],
                  'end':
                  storage_range[1]
                  }]
            storage_cidr = net_settings[constants.STORAGE_NETWORK]['cidr']
            self.netenv_obj[param_def]['StorageNetCidr'] = str(storage_cidr)
            if storage_cidr.version == 6:
                postfix = '/storage_v6.yaml'
            else:
                postfix = '/storage.yaml'
            if net_settings[constants.STORAGE_NETWORK]['vlan'] != 'native':
                self.netenv_obj[param_def]['StorageNetworkVlanID'] = \
                         net_settings[constants.STORAGE_NETWORK]['vlan']
        else:
            postfix = '/noop.yaml'

        for key, prefix in STORAGE_RESOURCES.items():
            if prefix is None:
                prefix = ''
            self.netenv_obj[reg][key] = tht_dir + prefix + postfix

        if constants.API_NETWORK in enabled_networks:
            api_range = net_settings[constants.API_NETWORK][
                'usable_ip_range'].split(',')
            self.netenv_obj[param_def]['InternalApiAllocationPools'] = \
                [{'start':
                      api_range[0],
                  'end':
                      api_range[1]
                  }]
            api_cidr = net_settings[constants.API_NETWORK]['cidr']
            self.netenv_obj[param_def]['InternalApiNetCidr'] = str(api_cidr)
            if api_cidr.version == 6:
                postfix = '/internal_api_v6.yaml'
            else:
                postfix = '/internal_api.yaml'
            if net_settings[constants.API_NETWORK]['vlan'] != 'native':
                self.netenv_obj[param_def]['InternalApiNetworkVlanID'] = \
                         net_settings[constants.API_NETWORK]['vlan']
        else:
            postfix = '/noop.yaml'

        for key, prefix in API_RESOURCES.items():
            if prefix is None:
                prefix = ''
            self.netenv_obj[reg][key] = tht_dir + prefix + postfix

        # Set IPv6 related flags to True. Not that we do not set those to False
        # when IPv4 is configured, we'll use the default or whatever the user
        # may have set.
        if settings_obj.get_ip_addr_family() == 6:
            for flag in IPV6_FLAGS:
                self.netenv_obj[param_def][flag] = True

    def get_netenv_settings(self):
        """
        Getter for netenv settings
        :return: Dictionary of network environment settings
        """
        return self.netenv_obj


class NetworkEnvException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
            return self.value
