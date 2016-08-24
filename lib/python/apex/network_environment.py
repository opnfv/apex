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
from .common.constants import (
    ADMIN_NETWORK,
    PRIVATE_NETWORK,
    STORAGE_NETWORK,
    PUBLIC_NETWORK,
    API_NETWORK,
    CONTROLLER_PRE,
    COMPUTE_PRE,
    PRE_CONFIG_DIR
)

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


class NetworkEnvironment(dict):
    """
    This class creates a Network Environment to be used in TripleO Heat
    Templates.

    The class builds upon an existing network-environment file and modifies
    based on a NetworkSettings object.
    """
    def __init__(self, net_settings, filename, compute_pre_config=False,
                 controller_pre_config=False):
        init_dict = {}
        if type(filename) is str:
            with open(filename, 'r') as net_env_fh:
                init_dict = yaml.load(net_env_fh)

        super().__init__(init_dict)
        try:
            enabled_networks = net_settings.enabled_network_list
        except:
            raise NetworkEnvException('Invalid Network Setting object')

        self.reg = self['resource_registry']
        self._set_tht_dir()

        param_def = self['parameter_defaults']
        enabled_networks = net_settings.get_enabled_networks()

        admin_cidr = net_settings[ADMIN_NETWORK]['cidr']
        admin_prefix = str(admin_cidr.prefixlen)
        param_def['ControlPlaneSubnetCidr'] = admin_prefix
        param_def['ControlPlaneDefaultRoute'] = \
            net_settings[ADMIN_NETWORK]['provisioner_ip']
        public_cidr = net_settings[PUBLIC_NETWORK]['cidr']
        param_def['ExternalNetCidr'] = str(public_cidr)
        if net_settings[PUBLIC_NETWORK]['vlan'] != 'native':
            param_def['NeutronExternalNetworkBridge'] = '""'
            param_def['ExternalNetworkVlanID'] = \
                net_settings[PUBLIC_NETWORK]['vlan']
        public_range = \
            net_settings[PUBLIC_NETWORK]['usable_ip_range'].split(',')
        param_def['ExternalAllocationPools'] = \
            [{'start':
              public_range[0],
              'end': public_range[1]
              }]
        param_def['ExternalInterfaceDefaultRoute'] = \
            net_settings[PUBLIC_NETWORK]['gateway']
        param_def['EC2MetadataIp'] = \
            net_settings[ADMIN_NETWORK]['provisioner_ip']
        param_def['DnsServers'] = net_settings['dns_servers']

        if public_cidr.version == 6:
            postfix = '/external_v6.yaml'
        else:
            postfix = '/external.yaml'

        # apply resource registry update for EXTERNAL_RESOURCES
        self._config_resource_reg(EXTERNAL_RESOURCES, postfix)

        if PRIVATE_NETWORK in enabled_networks:
            priv_range = net_settings[PRIVATE_NETWORK][
                'usable_ip_range'].split(',')
            param_def['TenantAllocationPools'] = \
                [{'start':
                  priv_range[0],
                  'end': priv_range[1]
                  }]
            priv_cidr = net_settings[PRIVATE_NETWORK]['cidr']
            param_def['TenantNetCidr'] = str(priv_cidr)
            if priv_cidr.version == 6:
                postfix = '/tenant_v6.yaml'
            else:
                postfix = '/tenant.yaml'
            if net_settings[PRIVATE_NETWORK]['vlan'] != 'native':
                param_def['TenantNetworkVlanID'] = \
                    net_settings[PRIVATE_NETWORK]['vlan']
        else:
            postfix = '/noop.yaml'

        # apply resource registry update for TENANT_RESOURCES
        self._config_resource_reg(TENANT_RESOURCES, postfix)

        if STORAGE_NETWORK in enabled_networks:
            storage_range = net_settings[STORAGE_NETWORK][
                'usable_ip_range'].split(',')
            param_def['StorageAllocationPools'] = \
                [{'start':
                  storage_range[0],
                  'end':
                  storage_range[1]
                  }]
            storage_cidr = net_settings[STORAGE_NETWORK]['cidr']
            param_def['StorageNetCidr'] = str(storage_cidr)
            if storage_cidr.version == 6:
                postfix = '/storage_v6.yaml'
            else:
                postfix = '/storage.yaml'
            if net_settings[STORAGE_NETWORK]['vlan'] != 'native':
                param_def['StorageNetworkVlanID'] = \
                    net_settings[STORAGE_NETWORK]['vlan']
        else:
            postfix = '/noop.yaml'

        # apply resource registry update for STORAGE_RESOURCES
        self._config_resource_reg(STORAGE_RESOURCES, postfix)

        if API_NETWORK in enabled_networks:
            api_range = net_settings[API_NETWORK][
                'usable_ip_range'].split(',')
            param_def['InternalApiAllocationPools'] = \
                [{'start': api_range[0],
                  'end': api_range[1]
                  }]
            api_cidr = net_settings[API_NETWORK]['cidr']
            param_def['InternalApiNetCidr'] = str(api_cidr)
            if api_cidr.version == 6:
                postfix = '/internal_api_v6.yaml'
            else:
                postfix = '/internal_api.yaml'
            if net_settings[API_NETWORK]['vlan'] != 'native':
                param_def['InternalApiNetworkVlanID'] = \
                    net_settings[API_NETWORK]['vlan']
        else:
            postfix = '/noop.yaml'

        # apply resource registry update for API_RESOURCES
        self._config_resource_reg(API_RESOURCES, postfix)

        if compute_pre_config:
            self.reg[COMPUTE_PRE] = PRE_CONFIG_DIR + "compute/numa.yaml"
        if controller_pre_config:
            self.reg[CONTROLLER_PRE] = PRE_CONFIG_DIR + "controller/numa.yaml"

        # Set IPv6 related flags to True. Not that we do not set those to False
        # when IPv4 is configured, we'll use the default or whatever the user
        # may have set.
        if net_settings.get_ip_addr_family() == 6:
            for flag in IPV6_FLAGS:
                param_def[flag] = True

    def _set_tht_dir(self):
        self.tht_dir = None
        for key, prefix in TENANT_RESOURCES.items():
            if prefix is None:
                prefix = ''
            m = re.split('%s/\w+\.yaml' % prefix, self.reg[key])
            if m is not None:
                self.tht_dir = m[0]
                break
        if not self.tht_dir:
            raise NetworkEnvException('Unable to parse THT Directory')

    def _config_resource_reg(self, resources, postfix):
        for key, prefix in resources.items():
            if prefix is None:
                prefix = ''
            self.reg[key] = self.tht_dir + prefix + postfix


class NetworkEnvException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
            return self.value
