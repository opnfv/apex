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
from .common import constants, utils


class NetworkSettings:
    """
    This class parses APEX network settings yaml file into an object. It
    generates or detects all missing fields for deployment.

    The resulting object will be used later to generate network environment file
    as well as configuring post deployment networks.

    Currently the parsed object is dumped into a bash global definition file
    for deploy.sh consumption. This object will later be used directly as
    deployment script move to python.
    """
    def __init__(self, filename, network_isolation):
        with open(filename, 'r') as network_settings_file:
            self.settings_obj = yaml.load(network_settings_file)
            self.network_isolation = network_isolation
            self.enabled_network_list = []
            self._validate_input()

    def _validate_input(self):
        """
        Validates the network settings file and populates all fields.

        NetworkSettingsException will be raised if validation fails.
        """
        if constants.ADMIN_NETWORK not in self.settings_obj or \
            not utils.str2bool(self.settings_obj[constants.ADMIN_NETWORK].get(
                    'enabled')):
            raise NetworkSettingsException("You must enable admin_network "
                                           "and configure it explicitly or "
                                           "use auto-detection")
        if self.network_isolation and \
            (constants.PUBLIC_NETWORK not in self.settings_obj or not
                utils.str2bool(self.settings_obj[constants.PUBLIC_NETWORK].get(
                    'enabled'))):
            raise NetworkSettingsException("You must enable public_network "
                                           "and configure it explicitly or "
                                           "use auto-detection")

        for network in constants.OPNFV_NETWORK_TYPES:
            if network in self.settings_obj:
                if utils.str2bool(self.settings_obj[network].get('enabled')):
                    logging.info("{} enabled".format(network))
                    self._config_required_settings(network)
                    self._config_ip_range(network=network,
                                          setting='usable_ip_range',
                                          start_offset=21, end_offset=21)
                    self._config_optional_settings(network)
                    self.enabled_network_list.append(network)
                else:
                    logging.info("{} disabled, will collapse with "
                                 "admin_network".format(network))
            else:
                logging.info("{} is not in specified, will collapse with "
                             "admin_network".format(network))

        self.settings_obj['dns_servers'] = self.settings_obj.get(
            'dns_servers', constants.DNS_SERVERS)

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
        if network is not constants.ADMIN_NETWORK:
            if 'vlan' not in self.settings_obj[network]:
                self.settings_obj[network]['lan'] = 'native'

        cidr = self.settings_obj[network].get('cidr')
        nic_name = self.settings_obj[network].get('bridged_interface')

        if cidr:
            cidr = ipaddress.ip_network(self.settings_obj[network]['cidr'])
            self.settings_obj[network]['cidr'] = cidr
            logging.info("{}_cidr: {}".format(network, cidr))
            return 0
        elif nic_name:
            # If cidr is not specified, we need to know if we should find
            # IPv6 or IPv4 address on the interface
            if utils.str2bool(self.settings_obj[network].get('ipv6')):
                address_family = 6
            else:
                address_family = 4
            nic_interface = ip_utils.get_interface(nic_name, address_family)
            if nic_interface:
                self.settings_obj[network]['bridged_interface'] = nic_interface
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
        ip_range = self.settings_obj[network].get(setting)
        interface = self.settings_obj[network].get('bridged_interface')

        if not ip_range:
            cidr = self.settings_obj[network].get('cidr')
            ip_range = ip_utils.get_ip_range(start_offset=start_offset,
                                             end_offset=end_offset,
                                             count=count,
                                             cidr=cidr,
                                             interface=interface)
            self.settings_obj[network][setting] = ip_range

        logging.info("{}_{}: {}".format(network, setting, ip_range))

    def _config_ip(self, network, setting, offset):
        """
        Configures IP for a given setting.

        If the setting is already specified, no change will be made.

        The spec for offset is identical to ip_utils.get_ip
        """
        ip = self.settings_obj[network].get(setting)
        interface = self.settings_obj[network].get('bridged_interface')

        if not ip:
            cidr = self.settings_obj[network].get('cidr')
            ip = ip_utils.get_ip(offset, cidr, interface)
            self.settings_obj[network][setting] = ip

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
            - floating_ip
            - gateway
        """
        if network == constants.ADMIN_NETWORK:
            self._config_ip(network, 'provisioner_ip', 1)
            self._config_ip_range(network=network, setting='dhcp_range',
                                  start_offset=2, count=9)
            self._config_ip_range(network=network,
                                  setting='introspection_range',
                                  start_offset=11, count=9)
        elif network == constants.PUBLIC_NETWORK:
            self._config_ip(network, 'provisioner_ip', 1)
            self._config_ip_range(network=network,
                                  setting='floating_ip',
                                  end_offset=2, count=20)
            self._config_gateway(network)

    def _config_gateway(self, network):
        """
        Configures gateway setting for a given network.

        If cidr is specified, we always use the first address in the address
        space for gateway. Otherwise, we detect the system gateway.
        """
        gateway = self.settings_obj[network].get('gateway')
        interface = self.settings_obj[network].get('bridged_interface')

        if not gateway:
            cidr = self.settings_obj[network].get('cidr')
            if cidr:
                gateway = ip_utils.get_ip(1, cidr)
            else:
                gateway = ip_utils.find_gateway(interface)

            if gateway:
                self.settings_obj[network]['gateway'] = gateway
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
            for key, value in self.settings_obj[network].items():
                bash_str += "{}_{}={}\n".format(network, key, value)
        bash_str += "enabled_network_list='{}'\n" \
            .format(' '.join(self.enabled_network_list))
        bash_str += "ip_addr_family={}\n".format(self.get_ip_addr_family())
        dns_list = ""
        for dns_server in self.settings_obj['dns_servers']:
            dns_list = dns_list + "{} ".format(dns_server)
        dns_list = dns_list.strip()
        bash_str += "dns_servers=\'{}\'\n".format(dns_list)
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
            cidr = ipaddress.ip_network(self.settings_obj[network]['cidr'])
            if cidr.version == 6:
                return 6

        return 4

    def get_network_settings(self):
        """
        Getter for network settings
        :return: network settings dictionary
        """
        return self.settings_obj

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



