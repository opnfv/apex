import logging

import neutronclient

import neutron_utils

logger = logging.getLogger('OpenStackNetwork')


class OpenStackNetwork:
    """
    Class responsible for creating a network in OpenStack

    All tasks have been designed after the vPing scenario in the OPNFV functest repository. We will want to make
    this class more flexible, expand it beyond the private network. Additionally, many of the private methods here
    should probably make their way into a file named something like neutron_utils.py.
    """

    def __init__(self, os_creds, network_settings, subnet_settings, router_settings):
        """
        Constructor - all parameters are required
        :param os_creds: The credentials to connect with OpenStack
        :param network_settings: The settings used to create a network
        :param subnet_settings: The settings used to create a subnet object (must be an instance of the
                                SubnetSettings class)
        :param router_settings: The settings used to create a router object (must be an instance of the
                                RouterSettings class)
        """
        self.os_creds = os_creds
        self.network_settings = network_settings
        self.subnet_settings = subnet_settings
        self.router_settings = router_settings
        self.neutron = neutron_utils.neutron_client(os_creds)
        self.neutron.format = 'json'

        # Attributes instantiated on create()
        self.network = None
        self.subnet = None
        self.router = None
        self.interface_router = None

    def create(self):
        """
        Responsible for creating not only the network but then a private subnet, router, and an interface to the router.
        """
        logger.info('Creating neutron network %s...' % self.network_settings.name)
        net_inst = neutron_utils.get_network_by_name(self.neutron, self.network_settings.name)
        if net_inst:
            self.network = net_inst
        else:
            self.network = neutron_utils.create_network(self.neutron, self.network_settings)
        logger.debug("Network '%s' created successfully" % self.network['network']['id'])

        logger.debug('Creating Subnet....')
        # TODO - Consider supporting multiple subnets for a single network
        sub_inst = neutron_utils.get_subnet_by_name(self.neutron, self.subnet_settings.name)
        if sub_inst:
            self.subnet = sub_inst
        else:
            self.subnet = neutron_utils.create_subnet(self.neutron, self.subnet_settings, self.network)
        logger.debug("Subnet '%s' created successfully" % self.subnet['subnets'][0]['id'])

        logger.debug('Creating Router...')
        if self.router_settings.name:
            router_inst = neutron_utils.get_router_by_name(self.neutron, self.router_settings.name)
            if router_inst:
                self.router = router_inst
            else:
                self.router = neutron_utils.create_router(self.neutron, self.router_settings)
            logger.debug("Router '%s' created successfully" % self.router['router']['id'])

            logger.debug('Adding router to subnet...')
            try:
                self.interface_router = neutron_utils.add_interface_router(self.neutron, self.router, self.subnet)
            except neutronclient.common.exceptions.BadRequest:
                pass

    def clean(self):
        """
        Removes and deletes all items created in reverse order.
        """
        neutron_utils.remove_interface_router(self.neutron, self.router, self.subnet)
        neutron_utils.delete_router(self.neutron, self.router)
        neutron_utils.delete_subnet(self.neutron, self.subnet)
        neutron_utils.delete_network(self.neutron, self.network)


class NetworkSettings:
    """
    Class representing a network configuration
    """

    def __init__(self, config=None, name=None, admin_state_up=True, shared=True, tenant_id=None):
        """
        Constructor - all parameters are optional
        :param config: Should be a dict object containing the configuration settings using the attribute names below
                       as each member's the key and overrides any of the other parameters.
        :param name: The network name.
        :param admin_state_up: The administrative status of the network. True = up / False = down (default True)
        :param shared: Boolean value indicating whether this network is shared across all tenants. By default, only
                       administrative users can change this value.
        :param tenant_id: Admin-only. The UUID of the tenant that will own the network. This tenant can be different
                          from the tenant that makes the create network request. However, only administrative users can
                          specify a tenant ID other than their own. You cannot change this value through authorization
                          policies.
        :return:
        """

        if config:
            self.name = config.get('name')
            self.admin_state_up = config.get('admin_state_up')
            self.shared = config.get('shared')
            self.tenant_id = config.get('tenant_id')
        else:
            self.name = name
            self.admin_state_up = admin_state_up
            self.shared = shared
            self.tenant_id = tenant_id

    def dict_for_neutron(self):
        """
        Returns a dictionary object representing this object.
        This is meant to be converted into JSON designed for use by the Neutron API

        TODO - expand automated testing to exercise all parameters

        :return: the dictionary object
        """
        out = dict()

        if self.name:
            out['name'] = self.name
        if self.admin_state_up:
            out['admin_state_up'] = self.admin_state_up
        # if self.shared:
        #     out['shared'] = self.shared
        if self.tenant_id:
            out['tenant_id'] = self.tenant_id
        return {'network': out}


class SubnetSettings:
    """
    Class representing a subnet configuration
    """

    def __init__(self, config=None, cidr=None, ip_version=4, name=None, tenant_id=None, allocation_pools=None,
                 start=None, end=None, gateway_ip=None, enable_dhcp=None, dns_nameservers=None, host_routes=None,
                 destination=None, nexthop=None, ipv6_ra_mode=None, ipv6_address_mode=None):
        """
        Constructor - all parameters are optional except cidr (subnet mask)
        :param config: Should be a dict object containing the configuration settings using the attribute names below
                       as each member's the key and overrides any of the other parameters.
        :param cidr: The CIDR. REQUIRED if config parameter is None
        :param ip_version: The IP version, which is 4 or 6.
        :param name: The subnet name.
        :param tenant_id: The ID of the tenant who owns the network. Only administrative users can specify a tenant ID
                          other than their own. You cannot change this value through authorization policies.
        :param allocation_pools: A dictionary containing the start and end addresses for the allocation pools.
        :param start: The start address for the allocation pools.
        :param end: The end address for the allocation pools.
        :param gateway_ip: The gateway IP address.
        :param enable_dhcp: Set to true if DHCP is enabled and false if DHCP is disabled.
        :param dns_nameservers: A list of DNS name servers for the subnet. Specify each name server as an IP address
                                and separate multiple entries with a space. For example [8.8.8.7 8.8.8.8].
        :param host_routes: A list of host route dictionaries for the subnet. For example:
                                "host_routes":[
                                    {
                                        "destination":"0.0.0.0/0",
                                        "nexthop":"123.456.78.9"
                                    },
                                    {
                                        "destination":"192.168.0.0/24",
                                        "nexthop":"192.168.0.1"
                                    }
                                ]
        :param destination: The destination for static route
        :param nexthop: The next hop for the destination.
        :param ipv6_ra_mode: A valid value is dhcpv6-stateful, dhcpv6-stateless, or slaac.
        :param ipv6_address_mode: A valid value is dhcpv6-stateful, dhcpv6-stateless, or slaac.
        :raise: Exception when config does not have or cidr values are None
        """
        if not dns_nameservers:
            dns_nameservers = ['8.8.8.8']

        if config:
            if config['cidr']:
                self.cidr = config['cidr']
                if config.get('ip_version'):
                    self.ip_version = config['ip_version']
                else:
                    self.ip_version = 4

                # Optional attributes that can be set after instantiation
                self.name = config.get('name')
                self.tenant_id = config.get('tenant_id')
                self.allocation_pools = config.get('allocation_pools')
                self.start = config.get('start')
                self.end = config.get('end')
                self.gateway_ip = config.get('gateway_ip')
                self.enable_dhcp = config.get('enable_dhcp')

                if config.get('dns_nameservers'):
                    self.dns_nameservers = config.get('dns_nameservers')
                else:
                    self.dns_nameservers = dns_nameservers

                self.host_routes = config.get('host_routes')
                self.destination = config.get('destination')
                self.nexthop = config.get('nexthop')
                self.ipv6_ra_mode = config.get('ipv6_ra_mode')
                self.ipv6_address_mode = config.get('ipv6_address_mode')
            else:
                raise Exception
        else:
            if cidr:
                # Required attributes
                self.cidr = cidr
                self.ip_version = ip_version

                # Optional attributes that can be set after instantiation
                self.name = name
                self.tenant_id = tenant_id
                self.allocation_pools = allocation_pools
                self.start = start
                self.end = end
                self.gateway_ip = gateway_ip
                self.enable_dhcp = enable_dhcp
                self.dns_nameservers = dns_nameservers
                self.host_routes = host_routes
                self.destination = destination
                self.nexthop = nexthop
                self.ipv6_ra_mode = ipv6_ra_mode
                self.ipv6_address_mode = ipv6_address_mode
            else:
                raise Exception

    def dict_for_neutron(self, network):
        """
        Returns a dictionary object representing this object.
        This is meant to be converted into JSON designed for use by the Neutron API
        :param network: (Optional) the network object on which the subnet will be created
        :return: the dictionary object
        """
        out = {
            'cidr': self.cidr,
            'ip_version': self.ip_version,
        }

        if network:
            out['network_id'] = network['network']['id']
        if self.name:
            out['name'] = self.name
        if self.tenant_id:
            out['tenant_id'] = self.tenant_id
        if self.allocation_pools and len(self.allocation_pools) > 0:
            out['allocation_pools'] = self.allocation_pools
        if self.start:
            out['start'] = self.start
        if self.end:
            out['end'] = self.end
        if self.gateway_ip:
            out['gateway_ip'] = self.gateway_ip
        if self.enable_dhcp:
            out['enable_dhcp'] = self.enable_dhcp
        if self.dns_nameservers and len(self.dns_nameservers) > 0:
            out['dns_nameservers'] = self.dns_nameservers
        if self.host_routes and len(self.host_routes) > 0:
            out['host_routes'] = self.host_routes
        if self.destination:
            out['destination'] = self.destination
        if self.nexthop:
            out['nexthop'] = self.nexthop
        if self.ipv6_ra_mode:
            out['ipv6_ra_mode'] = self.ipv6_ra_mode
        if self.ipv6_address_mode:
            out['ipv6_address_mode'] = self.ipv6_address_mode
        return out


class PortSettings:
    """
    Class representing a port configuration
    """

    def __init__(self, config=None, name=None, ip_address=None, admin_state_up=True, tenant_id=None, mac_address=None,
                 fixed_ips=None, security_groups=None, allowed_address_pairs=None, opt_value=None, opt_name=None,
                 device_owner=None, device_id=None):
        """
        Constructor - all parameters are optional
        :param config: Should be a dict object containing the configuration settings using the attribute names below
                       as each member's the key and overrides any of the other parameters.
        :param name: A symbolic name for the port.
        :param ip_address: If you specify both a subnet ID and an IP address, OpenStack Networking tries to allocate
                           the specified address to the port.
        :param admin_state_up: A boolean value denoting the administrative status of the port. True = up / False = down
        :param tenant_id: The ID of the tenant who owns the network. Only administrative users can specify a tenant ID
                          other than their own. You cannot change this value through authorization policies.
        :param mac_address: The MAC address. If you specify an address that is not valid, a Bad Request (400) status
                            code is returned. If you do not specify a MAC address, OpenStack Networking tries to
                            allocate one. If a failure occurs, a Service Unavailable (503) status code is returned.
        :param fixed_ips: A dictionary that allows one to specify only a subnet ID, OpenStack Networking allocates an
                          available IP from that subnet to the port. If you specify both a subnet ID and an IP address,
                          OpenStack Networking tries to allocate the specified address to the port
        :param security_groups: One or more security group IDs.
        :param allowed_address_pairs: A dictionary containing a set of zero or more allowed address pairs. An address
                                      pair contains an IP address and MAC address.
        :param opt_value: The extra DHCP option value.
        :param opt_name: The extra DHCP option name.
        :param device_owner: The ID of the entity that uses this port. For example, a DHCP agent.
        :param device_id: The ID of the device that uses this port. For example, a virtual server.
        :return:
        """

        port_config = None
        if config and config.get('port'):
            port_config = config.get('port')
        if port_config:
            self.name = port_config.get('name')
            self.ip_address = port_config.get('ip')
            self.admin_state_up = port_config.get('admin_state_up')
            self.tenant_id = port_config.get('tenant_id')
            self.mac_address = port_config.get('mac_address')
            self.fixed_ips = port_config.get('fixed_ips')
            self.security_groups = port_config.get('security_groups')
            self.allowed_address_pairs = port_config.get('allowed_address_pairs')
            self.opt_value = port_config.get('opt_value')
            self.opt_name = port_config.get('opt_name')
            self.device_owner = port_config.get('device_owner')
            self.device_id = port_config.get('device_id')
        else:
            self.name = name
            self.ip_address = ip_address
            self.admin_state_up = admin_state_up
            self.tenant_id = tenant_id
            self.mac_address = mac_address
            self.fixed_ips = fixed_ips
            self.security_groups = security_groups
            self.allowed_address_pairs = allowed_address_pairs
            self.opt_value = opt_value
            self.opt_name = opt_name
            self.device_owner = device_owner
            self.device_id = device_id

    def dict_for_neutron(self, network, subnet=None):
        """
        Returns a dictionary object representing this object.
        This is meant to be converted into JSON designed for use by the Neutron API

        TODO - expand automated testing to exercise all parameters

        :param network: (Required) the network object on which the port will be created
        :param subnet: (Optional) the subnet object on which the port will be created
        :return: the dictionary object
        """
        out = dict()

        if network:
            out['network_id'] = network['network']['id']
        # TODO/FIXME - specs say this is key/value is optional but the API call fails
        # if subnet:
        #     if len(subnet['subnets']) > 0:
        #         sub = subnet['subnets']
        #         out['subnet_id'] = sub[0]['id']
        if self.admin_state_up:
            out['admin_state_up'] = self.admin_state_up
        if self.name:
            out['name'] = self.name
        if self.ip_address and not self.fixed_ips:
            out['fixed_ips'] = [{"ip_address": self.ip_address}]
        if self.tenant_id:
            out['tenant_id'] = self.tenant_id
        if self.mac_address:
            out['mac_address'] = self.mac_address
        if self.fixed_ips and len(self.fixed_ips) > 0:
            out['fixed_ips'] = self.fixed_ips
            if self.ip_address:
                # TODO/FIXME - this hasn't been tested and looks to be dangerous
                out['fixed_ips'].append({"ip_address": self.ip_address})
        if self.security_groups:
            out['security_groups'] = self.security_groups
        if self.allowed_address_pairs and len(self.allowed_address_pairs) > 0:
            out['allowed_address_pairs'] = self.allowed_address_pairs
        if self.opt_value:
            out['opt_value'] = self.opt_value
        if self.opt_name:
            out['opt_name'] = self.opt_name
        if self.device_owner:
            out['device_owner'] = self.device_owner
        if self.device_id:
            out['device_id'] = self.device_id
        return {'port': out}


class RouterSettings:
    """
    Class representing a router configuration
    """

    def __init__(self, config=None, name=None, admin_state_up=True, external_gateway=None, enable_snat=True,
                 external_fixed_ips=None):
        """
        Constructor - all parameters are optional
        :param config: Should be a dict object containing the configuration settings using the attribute names below
                       as each member's the key and overrides any of the other parameters.
        :param name: The router name.
        :param admin_state_up: The administrative status of the router. True = up / False = down (default True)
        :param external_gateway: Dictionary containing the external gateway parameters, which include the
                                      network_id, enable_snat and external_fixed_ips parameters..
        :param enable_snat: Boolean value. Enable Source NAT (SNAT) attribute. Default is True. To persist this
                            attribute value, set the enable_snat_by_default option in the neutron.conf file.
        :param external_fixed_ips: Dictionary containing the IP address parameters.
        :return:
        """

        if config:
            self.name = config.get('name')
            self.admin_state_up = config.get('admin_state_up')
            self.external_gateway = config.get('external_gateway')
            self.enable_snat = config.get('enable_snat')
            self.external_fixed_ips = config.get('external_fixed_ips')
        else:
            self.name = name
            self.admin_state_up = admin_state_up
            self.external_gateway = external_gateway
            self.enable_snat = enable_snat
            self.external_fixed_ips = external_fixed_ips

    def dict_for_neutron(self, neutron):
        """
        Returns a dictionary object representing this object.
        This is meant to be converted into JSON designed for use by the Neutron API

        TODO - expand automated testing to exercise all parameters
        :param neutron: The neutron client to retrieve external network information if necessary
        :return: the dictionary object
        """
        out = dict()

        if self.name:
            out['name'] = self.name
        if self.admin_state_up:
            out['admin_state_up'] = self.admin_state_up
        if self.external_gateway:
            ext_net = neutron_utils.get_network_by_name(neutron, self.external_gateway)
            if ext_net:
                out['external_gateway_info'] = {'network_id': ext_net['network']['id']}

        # TODO/FIXME - specs say this is key/value is optional but the API call fails
        # if self.enable_snat:
        #     out['enable_snat'] = self.enable_snat
        if self.external_fixed_ips and len(self.external_fixed_ips) > 0:
            out['external_fixed_ips'] = self.external_fixed_ips
        return {'router': out}
