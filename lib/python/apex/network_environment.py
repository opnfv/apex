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
TENANT_RESOURCES = {'OS::TripleO::Network::Tenant': None,
                    'OS::TripleO::Controller::Ports::TenantPort': PORTS,
                    'OS::TripleO::Compute::Ports::TenantPort': PORTS}
STORAGE_RESOURCES = {'OS::TripleO::Network::Storage': None,
                     'OS::TripleO::Network::Ports::StorageVipPort': PORTS,
                     'OS::TripleO::Controller::Ports::StoragePort': PORTS,
                     'OS::TripleO::Compute::Ports::StoragePort': PORTS}


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
            if net_settings:
                settings_obj = net_settings.get_network_settings()
                enabled_networks = net_settings.get_enabled_networks()
                self.netenv_obj = \
                    self._update_net_environment(settings_obj,
                                                 enabled_networks)
            else:
                raise NetworkEnvException("Network Settings does not exist")

    def _update_net_environment(self, net_settings, enabled_networks):
        """
        Updates Network Environment according to Network Settings
        :param: network settings dictionary
        :param: enabled network list
        :return:  None
        """
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
        self.netenv_obj[param_def]['DnsServers'] = \
                net_settings['dns_servers']

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
            postfix = '/tenant.yaml'
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
            postfix = '/storage.yaml'
        else:
            postfix = '/noop.yaml'

        for key, prefix in STORAGE_RESOURCES.items():
            if prefix is None:
                prefix = ''
            self.netenv_obj[reg][key] = tht_dir + prefix + postfix
        return self.netenv_obj

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
