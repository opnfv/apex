import logging

from neutronclient.v2_0 import client as neutronclient

logger = logging.getLogger('neutron_utils')

"""
Utilities for basic neutron API calls
"""


def neutron_client(os_creds):
    """
    Instantiates and returns a client for communications with OpenStack's Neutron server
    :param os_creds: the credentials for connecting to the OpenStack remote API
    :return: the client object
    """
    return neutronclient.Client(**{
        'username': os_creds.username,
        'password': os_creds.password,
        'auth_url': os_creds.auth_url,
        'tenant_name': os_creds.tenant_name})


def create_network(neutron, network_settings):
    """
    Creates a network for OpenStack
    :param neutron: the client
    :param network_settings: A dictionary containing the network configuration and is responsible for creating the
                            network request JSON body
    :return: the network object
    """
    if neutron and network_settings:
        json_body = network_settings.dict_for_neutron()
        return neutron.create_network(body=json_body)
    else:
        logger.error("Failed to create network")
        raise Exception


def delete_network(neutron, network):
    """
    Deletes a network for OpenStack
    :param neutron: the client
    :param network: the network object
    """
    if neutron and network:
        neutron.delete_network(network['network']['id'])


def get_network_by_name(neutron, network_name):
    """
    Returns a network object (dictionary) of the first network found with a given name
    :param neutron: the client
    :param network_name: the name of the network to retrieve
    :return:
    """
    networks = neutron.list_networks()
    for network, netInsts in networks.iteritems():
        for inst in netInsts:
            if inst.get('name') == network_name:
                return {'network': inst}
    return None


def create_subnet(neutron, subnet_settings, network=None):
    """
    Creates a network subnet for OpenStack
    :param neutron: the client
    :param network: the network object
    :param subnet_settings: A dictionary containing the subnet configuration and is responsible for creating the subnet
                            request JSON body
    :return: the subnet object
    """
    if neutron and network and subnet_settings:
        json_body = {'subnets': [subnet_settings.dict_for_neutron(network)]}
        return neutron.create_subnet(body=json_body)
    else:
        logger.error("Failed to create subnet.")
        raise Exception


def delete_subnet(neutron, subnet):
    """
    Deletes a network subnet for OpenStack
    :param neutron: the client
    :param subnet: the subnet object
    """
    if neutron and subnet:
        neutron.delete_subnet(subnet['subnets'][0]['id'])


def get_subnet_by_name(neutron, subnet_name):
    """
    Returns a subnet object (dictionary) of the first subnet found with a given name
    :param neutron: the client
    :param subnet_name: the name of the network to retrieve
    :return:
    """
    subnets = neutron.list_subnets()
    for subnet, subnetInst in subnets.iteritems():
        for inst in subnetInst:
            if inst.get('name') == subnet_name:
                return {'subnets': [inst]}
    return None


def create_router(neutron, router_settings):
    """
    Creates a router for OpenStack
    :param neutron: the client
    :param router_settings: A dictionary containing the router configuration and is responsible for creating the subnet
                            request JSON body
    :return: the router object
    """
    if neutron:
        json_body = router_settings.dict_for_neutron(neutron)
        return neutron.create_router(json_body)
    else:
        logger.error("Failed to create router.")
        raise Exception


def delete_router(neutron, router):
    """
    Deletes a router for OpenStack
    :param neutron: the client
    :param router: the router object
    """
    if neutron and router:
        neutron.delete_router(router=router['router']['id'])
        return True


def get_router_by_name(neutron, router_name):
    """
    Returns a subnet object (dictionary) of the first subnet found with a given name
    :param neutron: the client
    :param router_name: the name of the network to retrieve
    :return:
    """
    routers = neutron.list_routers()
    for router, routerInst in routers.iteritems():
        for inst in routerInst:
            if inst.get('name') == router_name:
                return {'router': inst}
    return None


def add_interface_router(neutron, router, subnet):
    """
    Adds an interface router for OpenStack
    :param neutron: the client
    :param router: the router object
    :param subnet: the subnet object
    :return: the interface router object
    """
    if neutron and router and subnet:
        # TODO - This will have to change if we are to support multiple subnets per router
        json_body = {"subnet_id": subnet['subnets'][0]['id']}
        return neutron.add_interface_router(router=router['router']['id'], body=json_body)
    else:
        logger.error("Unable to create interface router as neutron client, router or subnet were not created")
        raise Exception


def remove_interface_router(neutron, router, subnet):
    """
    Removes an interface router for OpenStack
    :param neutron: the client
    :param router: the router object
    :param subnet: the subnet object
    """
    if neutron and router and subnet:
        # TODO - This will have to change if we are to support multiple subnets per router
        json_body = {"subnet_id": subnet['subnets'][0]['id']}
        neutron.remove_interface_router(router=router['router']['id'], body=json_body)


def create_port(neutron, port_settings, network, subnet=None):
    """
    Creates a port for OpenStack
    :param neutron: the client
    :param port_settings: the settings object for port configuration
    :param network: (Optional) the associated network object
    :param subnet: (Optional) the associated subnet object
    :return: the port object
    """
    json_body = port_settings.dict_for_neutron(network, subnet)
    return neutron.create_port(body=json_body)


def delete_port(neutron, port):
    """
    Removes an OpenStack port
    :param neutron: the client
    :param port: the port object
    :return:
    """
    neutron.delete_port(port['port']['id'])
