##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import re
import yaml

from apex.settings.network_settings import NetworkSettings
from apex.common.constants import (
    CONTROLLER,
    COMPUTE,
    ADMIN_NETWORK,
    TENANT_NETWORK,
    STORAGE_NETWORK,
    EXTERNAL_NETWORK,
    API_NETWORK,
    DEFAULT_OS_VERSION,
)

HEAT_NONE = 'OS::Heat::None'
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
STORAGE_MGMT_RESOURCES = {
    'OS::TripleO::Network::StorageMgmt': None,
    'OS::TripleO::Network::Ports::StorageMgmtVipPort': PORTS,
    'OS::TripleO::Controller::Ports::StorageMgmtPort': PORTS,
    'OS::TripleO::Compute::Ports::StorageMgmtPort': PORTS
}

# A list of flags that will be set to true when IPv6 is enabled
IPV6_FLAGS = ["NovaIPv6", "MongoDbIPv6", "CorosyncIPv6", "CephIPv6",
              "RabbitIPv6", "MemcachedIPv6"]

reg = 'resource_registry'
param_def = 'parameter_defaults'


class NetworkEnvironment(dict):
    """
    This class creates a Network Environment to be used in TripleO Heat
    Templates.

    The class builds upon an existing network-environment file and modifies
    based on a NetworkSettings object.
    """
    def __init__(self, net_settings, filename, compute_pre_config=False,
                 controller_pre_config=False, os_version=DEFAULT_OS_VERSION):
        """
        Create Network Environment according to Network Settings
        """
        init_dict = {}
        if not isinstance(net_settings, NetworkSettings):
            raise NetworkEnvException('Invalid Network Settings object')
        if isinstance(filename, str):
            with open(filename, 'r') as net_env_fh:
                init_dict = yaml.safe_load(net_env_fh)
        super().__init__(init_dict)
        self._set_tht_dir()
        nets = net_settings['networks']
        self.os_version = os_version
        admin_cidr = nets[ADMIN_NETWORK]['cidr']
        admin_prefix = str(admin_cidr.prefixlen)
        self[param_def]['ControlPlaneSubnetCidr'] = admin_prefix
        self[param_def]['ControlPlaneDefaultRoute'] = \
            nets[ADMIN_NETWORK]['gateway']
        self[param_def]['EC2MetadataIp'] = \
            nets[ADMIN_NETWORK]['installer_vm']['ip']
        self[param_def]['DnsServers'] = net_settings['dns_servers']

        if EXTERNAL_NETWORK in net_settings.enabled_network_list:
            external_cidr = net_settings.get_network(EXTERNAL_NETWORK)['cidr']
            self[param_def]['ExternalNetCidr'] = str(external_cidr)
            external_vlan = self._get_vlan(net_settings.get_network(
                                           EXTERNAL_NETWORK))
            if isinstance(external_vlan, int):
                self[param_def]['NeutronExternalNetworkBridge'] = '""'
                self[param_def]['ExternalNetworkVlanID'] = external_vlan
            external_range = net_settings.get_network(EXTERNAL_NETWORK)[
                'overcloud_ip_range']
            self[param_def]['ExternalAllocationPools'] = \
                [{'start': str(external_range[0]),
                  'end': str(external_range[1])}]
            self[param_def]['ExternalInterfaceDefaultRoute'] = \
                net_settings.get_network(EXTERNAL_NETWORK)['gateway']

            if external_cidr.version == 6:
                postfix = '/external_v6.yaml'
            else:
                postfix = '/external.yaml'
        else:
            postfix = '/noop.yaml'

        # apply resource registry update for EXTERNAL_RESOURCES
        self._config_resource_reg(EXTERNAL_RESOURCES, postfix)

        if TENANT_NETWORK in net_settings.enabled_network_list:
            tenant_range = nets[TENANT_NETWORK]['overcloud_ip_range']
            self[param_def]['TenantAllocationPools'] = \
                [{'start': str(tenant_range[0]),
                  'end': str(tenant_range[1])}]
            tenant_cidr = nets[TENANT_NETWORK]['cidr']
            self[param_def]['TenantNetCidr'] = str(tenant_cidr)
            if tenant_cidr.version == 6:
                postfix = '/tenant_v6.yaml'
                # set overlay_ip_version option in Neutron ML2 config
                self[param_def]['NeutronOverlayIPVersion'] = "6"
            else:
                postfix = '/tenant.yaml'

            tenant_vlan = self._get_vlan(nets[TENANT_NETWORK])
            if isinstance(tenant_vlan, int):
                self[param_def]['TenantNetworkVlanID'] = tenant_vlan
        else:
            postfix = '/noop.yaml'

        # apply resource registry update for TENANT_RESOURCES
        self._config_resource_reg(TENANT_RESOURCES, postfix)

        if STORAGE_NETWORK in net_settings.enabled_network_list:
            storage_range = nets[STORAGE_NETWORK]['overcloud_ip_range']
            self[param_def]['StorageAllocationPools'] = \
                [{'start': str(storage_range[0]),
                  'end': str(storage_range[1])}]
            storage_cidr = nets[STORAGE_NETWORK]['cidr']
            self[param_def]['StorageNetCidr'] = str(storage_cidr)
            if storage_cidr.version == 6:
                postfix = '/storage_v6.yaml'
            else:
                postfix = '/storage.yaml'
            storage_vlan = self._get_vlan(nets[STORAGE_NETWORK])
            if isinstance(storage_vlan, int):
                self[param_def]['StorageNetworkVlanID'] = storage_vlan
        else:
            postfix = '/noop.yaml'

        # apply resource registry update for STORAGE_RESOURCES
        self._config_resource_reg(STORAGE_RESOURCES, postfix)

        if API_NETWORK in net_settings.enabled_network_list:
            api_range = nets[API_NETWORK]['overcloud_ip_range']
            self[param_def]['InternalApiAllocationPools'] = \
                [{'start': str(api_range[0]),
                  'end': str(api_range[1])}]
            api_cidr = nets[API_NETWORK]['cidr']
            self[param_def]['InternalApiNetCidr'] = str(api_cidr)
            if api_cidr.version == 6:
                postfix = '/internal_api_v6.yaml'
            else:
                postfix = '/internal_api.yaml'
            api_vlan = self._get_vlan(nets[API_NETWORK])
            if isinstance(api_vlan, int):
                self[param_def]['InternalApiNetworkVlanID'] = api_vlan
        else:
            postfix = '/noop.yaml'

        # apply resource registry update for API_RESOURCES
        self._config_resource_reg(API_RESOURCES, postfix)

        if self.os_version != 'ocata':
            self._config_resource_reg(STORAGE_MGMT_RESOURCES, '/noop.yaml')

        # Set IPv6 related flags to True. Not that we do not set those to False
        # when IPv4 is configured, we'll use the default or whatever the user
        # may have set.
        if net_settings.get_ip_addr_family() == 6:
            for flag in IPV6_FLAGS:
                self[param_def][flag] = True

    def _get_vlan(self, network):
        if isinstance(network['nic_mapping'][CONTROLLER]['vlan'], int):
            return network['nic_mapping'][CONTROLLER]['vlan']
        elif isinstance(network['nic_mapping'][COMPUTE]['vlan'], int):
            return network['nic_mapping'][COMPUTE]['vlan']
        else:
            return 'native'

    def _set_tht_dir(self):
        self.tht_dir = None
        for key, prefix in TENANT_RESOURCES.items():
            if prefix is None:
                prefix = ''
            m = re.split('%s/\w+\.yaml' % prefix, self[reg][key])
            if m is not None and len(m) > 1:
                self.tht_dir = m[0]
                break
        if not self.tht_dir:
            raise NetworkEnvException('Unable to parse THT Directory')

    def _config_resource_reg(self, resources, postfix):
        for key, prefix in resources.items():
            if prefix is None:
                if postfix == '/noop.yaml':
                    if self.os_version == 'ocata':
                        self[reg][key] = HEAT_NONE
                    else:
                        del self[reg][key]
                    continue
                prefix = ''
            self[reg][key] = self.tht_dir + prefix + postfix


class NetworkEnvException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
            return self.value
