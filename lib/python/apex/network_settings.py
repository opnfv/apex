##############################################################################
# Copyright (c) 2016 Feng Pan (fpan@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import yaml
import logging
import ipaddress
from . import ip_utils
from .common.utils import str2bool
from .common.constants import (
        ADMIN_NETWORK,
        PRIVATE_NETWORK,
        PUBLIC_NETWORK,
        STORAGE_NETWORK,
        API_NETWORK,
        OPNFV_NETWORK_TYPES,
        DNS_SERVERS,
        DOMAIN_NAME,
        ROLES,
        COMPUTE,
        CONTROLLER)


class NetworkSettings(dict):
    """
    This class parses APEX network settings yaml file into an object. It
    generates or detects all missing fields for deployment.

    The resulting object will be used later to generate network environment
    file as well as configuring post deployment networks.

    Currently the parsed object is dumped into a bash global definition file
    for deploy.sh consumption. This object will later be used directly as
    deployment script move to python.
    """
    def __init__(self, filename, network_isolation):
        init_dict = {}
        if type(filename) is str:
            with open(filename, 'r') as network_settings_file:
                init_dict = yaml.load(network_settings_file)
        else:
            # assume input is a dict to build from
            init_dict = filename

        super().__init__(init_dict)

        if 'apex' in self:
            # merge two dics Nondestructively
            def merge(pri, sec):
                for key, val in sec.items():
                    if key in pri:
                        if type(val) is dict:
                            merge(pri[key], val)
                        #else
                        # do not overwrite what's already there
                    else:
                        pri[key] = val
            # merge the apex specific config into the first class settings
            merge(self, copy(self['apex']))

        self.network_isolation = network_isolation
        self.enabled_network_list = []
        self.nics = {COMPUTE: {}, CONTROLLER: {}}
        self.nics_specified = {COMPUTE: False, CONTROLLER: False}
        self._validate_input()


    def _validate_input(self):
        """
        Validates the network settings file and populates all fields.

        NetworkSettingsException will be raised if validation fails.
        """
        if ADMIN_NETWORK not in self or \
            not str2bool(self[ADMIN_NETWORK].get(
                'enabled')):
            raise NetworkSettingsException("You must enable admin_network "
                                           "and configure it explicitly or "
                                           "use auto-detection")
        if self.network_isolation and \
            (PUBLIC_NETWORK not in self or not
                str2bool(self[PUBLIC_NETWORK].get(
                    'enabled'))):
            raise NetworkSettingsException("You must enable public_network "
                                           "and configure it explicitly or "
                                           "use auto-detection")

        for network in OPNFV_NETWORK_TYPES:
            if network in self:
                if str2bool(self[network].get('enabled')):
                    logging.info("{} enabled".format(network))
                    self._config_required_settings(network)
                    self._config_ip_range(network=network,
                                          setting='usable_ip_range',
                                          start_offset=21, end_offset=21)
                    self._config_optional_settings(network)
                    self.enabled_network_list.append(network)
                    self._validate_overcloud_nic_order(network)
                else:
                    logging.info("{} disabled, will collapse with "
                                 "admin_network".format(network))
            else:
                logging.info("{} is not in specified, will collapse with "
                             "admin_network".format(network))

        self['dns_servers'] = self.get('dns_servers', DNS_SERVERS)
        self['domain_name'] = self.get('domain_name', DOMAIN_NAME)

    def _validate_overcloud_nic_order(self, network):
        """
        Detects if nic order is specified per profile (compute/controller)
        for network

        If nic order is specified in a network for a profile, it should be
        specified for every network with that profile other than admin_network

        Duplicate nic names are also not allowed across different networks

        :param network: network to detect if nic order present
        :return: None
        """

        for role in ROLES:
            interface = role+'_interface'
            nic_index = self.get_enabled_networks().index(network) + 1
            if interface in self[network]:
                if any(y == self[network][interface] for x, y in
                       self.nics[role].items()):
                    raise NetworkSettingsException("Duplicate {} already "
                                                   "specified for "
                                                   "another network"
                                                   .format(self[network]
                                                           [interface]))
                self.nics[role][network] = self[network][interface]
                self.nics_specified[role] = True
                logging.info("{} nic order specified for network {"
                             "}".format(role, network))
            elif self.nics_specified[role]:
                logging.error("{} nic order not specified for network {"
                              "}".format(role, network))
                raise NetworkSettingsException("Must specify {} for all "
                                               "enabled networks (other than "
                                               " admin) or not specify it for "
                                               "any".format(interface))
            else:
                logging.info("{} nic order not specified for network {"
                             "}. Will use logical default "
                             "nic{}".format(interface, network, nic_index))
                self.nics[role][network] = 'nic' + str(nic_index)
                nic_index += 1

    def _config_required_settings(self, network):
        """
        Configures either CIDR or bridged_interface setting

        cidr takes precedence if both cidr and bridged_interface are specified
        for a given network.

        When using bridged_interface, we will detect network setting on the
        given NIC in the system. The resulting config in settings object will
        be an ipaddress.network object, replacing the NIC name.
        """
        # if vlan not defined then default it to native
        if network is not ADMIN_NETWORK:
            if 'vlan' not in self[network]:
                self[network]['vlan'] = 'native'

        cidr = self[network].get('cidr')
        nic_name = self[network].get('bridged_interface')

        if cidr:
            cidr = ipaddress.ip_network(self[network]['cidr'])
            self[network]['cidr'] = cidr
            logging.info("{}_cidr: {}".format(network, cidr))
            return 0
        elif nic_name:
            # If cidr is not specified, we need to know if we should find
            # IPv6 or IPv4 address on the interface
            if str2bool(self[network].get('ipv6')):
                address_family = 6
            else:
                address_family = 4
            nic_interface = ip_utils.get_interface(nic_name, address_family)
            if nic_interface:
                self[network]['bridged_interface'] = nic_interface
                logging.info("{}_bridged_interface: {}".
                             format(network, nic_interface))
                return 0
            else:
                raise NetworkSettingsException("Auto detection failed for {}: "
                                               "Unable to find valid ip for "
                                               "interface {}"
                                               .format(network, nic_name))

        else:
            raise NetworkSettingsException("Auto detection failed for {}: "
                                           "either bridge_interface or cidr "
                                           "must be specified"
                                           .format(network))

    def _config_ip_range(self, network, setting, start_offset=None,
                         end_offset=None, count=None):
        """
        Configures IP range for a given setting.

        If the setting is already specified, no change will be made.

        The spec for start_offset, end_offset and count are identical to
        ip_utils.get_ip_range.
        """
        ip_range = self[network].get(setting)
        interface = self[network].get('bridged_interface')

        if not ip_range:
            cidr = self[network].get('cidr')
            ip_range = ip_utils.get_ip_range(start_offset=start_offset,
                                             end_offset=end_offset,
                                             count=count,
                                             cidr=cidr,
                                             interface=interface)
            self[network][setting] = ip_range

        logging.info("{}_{}: {}".format(network, setting, ip_range))

    def _config_ip(self, network, setting, offset):
        """
        Configures IP for a given setting.

        If the setting is already specified, no change will be made.

        The spec for offset is identical to ip_utils.get_ip
        """
        ip = self[network].get(setting)
        interface = self[network].get('bridged_interface')

        if not ip:
            cidr = self[network].get('cidr')
            ip = ip_utils.get_ip(offset, cidr, interface)
            self[network][setting] = ip

        logging.info("{}_{}: {}".format(network, setting, ip))

    def _config_optional_settings(self, network):
        """
        Configures optional settings:
        - admin_network:
            - provisioner_ip
            - dhcp_range
            - introspection_range
        - public_network:
            - provisioner_ip
            - floating_ip_range
            - gateway
        """
        if network == ADMIN_NETWORK:
            self._config_ip(network, 'provisioner_ip', 1)
            self._config_ip_range(network=network, setting='dhcp_range',
                                  start_offset=2, count=9)
            self._config_ip_range(network=network,
                                  setting='introspection_range',
                                  start_offset=11, count=9)
        elif network == PUBLIC_NETWORK:
            self._config_ip(network, 'provisioner_ip', 1)
            self._config_ip_range(network=network,
                                  setting='floating_ip_range',
                                  end_offset=2, count=20)
            self._config_gateway(network)

    def _config_gateway(self, network):
        """
        Configures gateway setting for a given network.

        If cidr is specified, we always use the first address in the address
        space for gateway. Otherwise, we detect the system gateway.
        """
        gateway = self[network].get('gateway')
        interface = self[network].get('bridged_interface')

        if not gateway:
            cidr = self[network].get('cidr')
            if cidr:
                gateway = ip_utils.get_ip(1, cidr)
            else:
                gateway = ip_utils.find_gateway(interface)

            if gateway:
                self[network]['gateway'] = gateway
            else:
                raise NetworkSettingsException("Failed to set gateway")

        logging.info("{}_gateway: {}".format(network, gateway))

    def dump_bash(self, path=None):
        """
        Prints settings for bash consumption.

        If optional path is provided, bash string will be written to the file
        instead of stdout.
        """
        bash_str = ''
        for network in self.enabled_network_list:
            for key, value in self[network].items():
                bash_str += "{}_{}={}\n".format(network, key, value)
        bash_str += "enabled_network_list='{}'\n" \
            .format(' '.join(self.enabled_network_list))
        bash_str += "ip_addr_family={}\n".format(self.get_ip_addr_family())
        dns_list = ""
        for dns_server in self['dns_servers']:
            dns_list = dns_list + "{} ".format(dns_server)
        dns_list = dns_list.strip()
        bash_str += "dns_servers=\'{}\'\n".format(dns_list)
        bash_str += "domain_name=\'{}\'\n".format(self['domain_name'])
        if path:
            with open(path, 'w') as file:
                file.write(bash_str)
        else:
            print(bash_str)

    def get_ip_addr_family(self):
        """
        Returns IP address family for current deployment.

        If any enabled network has IPv6 CIDR, the deployment is classified as
        IPv6.
        """
        for network in self.enabled_network_list:
            cidr = ipaddress.ip_network(self[network]['cidr'])
            if cidr.version == 6:
                return 6

        return 4

    def get_enabled_networks(self):
        """
        Getter for enabled network list
        :return: list of enabled networks
        """
        return self.enabled_network_list


class NetworkSettingsException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
            return self.value
