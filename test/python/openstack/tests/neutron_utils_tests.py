import logging
import unittest

from openstack import neutron_utils
from openstack import create_network
from openstack.tests import openstack_tests


# Initialize Logging
logging.basicConfig(level=logging.DEBUG)

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# To run these tests, the CWD must be set to the top level directory of this project
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

os_creds = openstack_tests.get_credentials()

port_name = 'test-port-name'
ip_1 = '10.55.1.100'
ip_2 = '10.55.1.200'


class NeutronUtilsTests(unittest.TestCase):
    """
    Test for the CreateImage class defined in create_image.py
    """

    def setUp(self):
        """
        Instantiates the CreateImage object that is responsible for downloading and creating an OS image file
        within OpenStack
        """
        self.neutron = neutron_utils.neutron_client(os_creds)
        self.network = None
        self.subnet = None
        self.port = None
        self.router = None
        self.interface_router = None
        self.net_config = openstack_tests.get_pub_net_config()

    def tearDown(self):
        """
        Cleans the remote OpenStack objects
        """
        if self.interface_router:
            neutron_utils.remove_interface_router(self.neutron, self.router, self.subnet)

        if self.router:
            neutron_utils.delete_router(self.neutron, self.router)
            validate_router(self.neutron, self.router.get('name'), False)

        if self.port:
            neutron_utils.delete_port(self.neutron, self.port)

        if self.subnet:
            neutron_utils.delete_subnet(self.neutron, self.subnet)
            validate_subnet(self.neutron, self.subnet.get('name'), self.net_config.subnet_cidr, False)

        if self.network:
            neutron_utils.delete_network(self.neutron, self.network)
            validate_network(self.neutron, self.network['network']['name'], False)

    def test_create_network(self):
        """
        Tests the neutron_utils.create_neutron_net() function
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

    def test_create_network_empty_name(self):
        """
        Tests the neutron_utils.create_neutron_net() function with an empty network name
        """
        self.network = neutron_utils.create_network(self.neutron, create_network.NetworkSettings(name=''))
        self.assertEqual('', self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, '', True))

    def test_create_network_null_name(self):
        """
        Tests the neutron_utils.create_neutron_net() function when the network name is None
        """
        self.network = neutron_utils.create_network(self.neutron, create_network.NetworkSettings())
        this_net_name = self.network['network'].get('name')
        self.assertEqual(u'', this_net_name)
        self.assertTrue(validate_network(self.neutron, this_net_name, True))

    def test_create_subnet(self):
        """
        Tests the neutron_utils.create_neutron_net() function
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, network=self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

    def test_create_subnet_null_name(self):
        """
        Tests the neutron_utils.create_neutron_subnet() function for an Exception when the subnet name is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        sub_sets = create_network.SubnetSettings(cidr=self.net_config.subnet_cidr)
        self.subnet = neutron_utils.create_subnet(self.neutron, sub_sets, network=self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

    def test_create_subnet_empty_name(self):
        """
        Tests the neutron_utils.create_neutron_net() function with an empty name
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, network=self.network)
        validate_subnet(self.neutron, '', self.net_config.subnet_cidr, True)

    def test_create_subnet_null_cidr(self):
        """
        Tests the neutron_utils.create_neutron_subnet() function for an Exception when the subnet CIDR value is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        with self.assertRaises(Exception):
            sub_sets = create_network.SubnetSettings(cidr=None, name=self.net_config.subnet_name)
            neutron_utils.create_subnet(self.neutron, sub_sets, network=self.network)

    def test_create_subnet_empty_cidr(self):
        """
        Tests the neutron_utils.create_neutron_subnet() function for an Exception when the subnet CIDR value is empty
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        with self.assertRaises(Exception):
            sub_sets = create_network.SubnetSettings(cidr='', name=self.net_config.subnet_name)
            neutron_utils.create_subnet(self.neutron, sub_sets, network=self.network)

    def test_create_router_simple(self):
        """
        Tests the neutron_utils.create_neutron_net() function when an external gateway is requested
        """
        self.router = neutron_utils.create_router(self.neutron, self.net_config.router_settings)
        validate_router(self.neutron, self.net_config.router_name, True)

    def test_create_router_with_public_interface(self):
        """
        Tests the neutron_utils.create_neutron_net() function when an external gateway is requested
        """
        self.net_config = openstack_tests.OSNetworkConfig('test-priv-net', 'test-priv-subnet', '10.2.1.0/24',
                                                          'test-router', 'external')
        self.router = neutron_utils.create_router(self.neutron, self.net_config.router_settings)
        validate_router(self.neutron, self.net_config.router_name, True)
        # TODO - Add validation that the router gatway has been set

    def test_create_router_empty_name(self):
        """
        Tests the neutron_utils.create_neutron_net() function
        """
        this_router_settings = create_network.RouterSettings(name='')
        self.router = neutron_utils.create_router(self.neutron, this_router_settings)
        validate_router(self.neutron, '', True)

    def test_create_router_null_name(self):
        """
        Tests the neutron_utils.create_neutron_subnet() function when the subnet CIDR value is None
        """
        this_router_settings = create_network.RouterSettings()
        self.router = neutron_utils.create_router(self.neutron, this_router_settings)
        validate_router(self.neutron, None, True)

    def test_add_interface_router(self):
        """
        Tests the neutron_utils.add_interface_router() function
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        self.router = neutron_utils.create_router(self.neutron, self.net_config.router_settings)
        validate_router(self.neutron, self.net_config.router_name, True)

        self.interface_router = neutron_utils.add_interface_router(self.neutron, self.router, self.subnet)
        validate_interface_router(self.interface_router, self.router, self.subnet)

    def test_add_interface_router_null_router(self):
        """
        Tests the neutron_utils.add_interface_router() function for an Exception when the router value is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        with self.assertRaises(Exception):
            self.interface_router = neutron_utils.add_interface_router(self.neutron, self.router, self.subnet)

    def test_add_interface_router_null_subnet(self):
        """
        Tests the neutron_utils.add_interface_router() function for an Exception when the subnet value is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.router = neutron_utils.create_router(self.neutron, self.net_config.router_settings)
        validate_router(self.neutron, self.net_config.router_name, True)

        with self.assertRaises(Exception):
            self.interface_router = neutron_utils.add_interface_router(self.neutron, self.router, self.subnet)

    def test_create_port(self):
        """
        Tests the neutron_utils.create_port() function
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        self.port = neutron_utils.create_port(self.neutron,
                                              create_network.PortSettings(name=port_name, ip_address=ip_1),
                                              network=self.network, subnet=self.subnet)
        validate_port(self.neutron, port_name, True)

    def test_create_port_empty_name(self):
        """
        Tests the neutron_utils.create_port() function
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        self.port = neutron_utils.create_port(self.neutron, create_network.PortSettings(ip_address=ip_1), self.network)
        validate_port(self.neutron, port_name, True)

    def test_create_port_null_name(self):
        """
        Tests the neutron_utils.create_port() function for an Exception when the port name value is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        with self.assertRaises(Exception):
            self.port = neutron_utils.create_port(self.neutron, None, self.network, ip_1)

    def test_create_port_null_network_object(self):
        """
        Tests the neutron_utils.create_port() function for an Exception when the network object is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        with self.assertRaises(Exception):
            self.port = neutron_utils.create_port(self.neutron, port_name, None, ip_1)

    def test_create_port_null_ip(self):
        """
        Tests the neutron_utils.create_port() function for an Exception when the IP value is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        with self.assertRaises(Exception):
            self.port = neutron_utils.create_port(self.neutron, port_name, self.network, None)

    def test_create_port_invalid_ip(self):
        """
        Tests the neutron_utils.create_port() function for an Exception when the IP value is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        with self.assertRaises(Exception):
            self.port = neutron_utils.create_port(self.neutron, port_name, self.network, 'foo')

    def test_create_port_invalid_ip_to_subnet(self):
        """
        Tests the neutron_utils.create_port() function for an Exception when the IP value is None
        """
        self.network = neutron_utils.create_network(self.neutron, self.net_config.network_settings)
        self.assertEqual(self.net_config.net_name, self.network['network']['name'])
        self.assertTrue(validate_network(self.neutron, self.net_config.net_name, True))

        self.subnet = neutron_utils.create_subnet(self.neutron, self.net_config.subnet_settings, self.network)
        validate_subnet(self.neutron, self.net_config.subnet_name, self.net_config.subnet_cidr, True)

        with self.assertRaises(Exception):
            self.port = neutron_utils.create_port(self.neutron, port_name, self.network, '10.197.123.100')


"""
Validation routines
"""


def validate_network(neutron, name, exists):
    """
    Returns true if a network for a given name DOES NOT exist if the exists parameter is false conversely true.
    Returns false if a network for a given name DOES exist if the exists parameter is true conversely false.
    :param neutron: The neutron client
    :param name: The expected network name
    :param exists: Whether or not the network name should exist or not
    :return: True/False
    """
    network = neutron_utils.get_network_by_name(neutron, name)
    if exists and network:
        return True
    if not exists and not network:
        return True
    return False


def validate_subnet(neutron, name, cidr, exists):
    """
    Returns true if a subnet for a given name DOES NOT exist if the exists parameter is false conversely true.
    Returns false if a subnet for a given name DOES exist if the exists parameter is true conversely false.
    :param neutron: The neutron client
    :param name: The expected subnet name
    :param cidr: The expected CIDR value
    :param exists: Whether or not the network name should exist or not
    :return: True/False
    """
    subnet = neutron_utils.get_subnet_by_name(neutron, name)
    if exists and subnet:
        return subnet.get('cidr') == cidr
    if not exists and not subnet:
        return True
    return False


def validate_router(neutron, name, exists):
    """
    Returns true if a router for a given name DOES NOT exist if the exists parameter is false conversely true.
    Returns false if a router for a given name DOES exist if the exists parameter is true conversely false.
    :param neutron: The neutron client
    :param name: The expected router name
    :param exists: Whether or not the network name should exist or not
    :return: True/False
    """
    router = neutron_utils.get_router_by_name(neutron, name)
    if exists and router:
        return True
    return False


def validate_interface_router(interface_router, router, subnet):
    """
    Returns true if the router ID & subnet ID have been properly included into the interface router object
    :param interface_router: the object to validate
    :param router: to validate against the interface_router
    :param subnet: to validate against the interface_router
    :return: True if both IDs match else False
    """
    subnet_id = interface_router.get('subnet_id')
    router_id = interface_router.get('port_id')

    return subnet.get('id') == subnet_id and router.get('id') == router_id


def validate_port(neutron, name, exists):
    """
    Returns true if a port for a given name DOES NOT exist if the exists parameter is false conversely true.
    Returns false if a port for a given name DOES exist if the exists parameter is true conversely false.
    :param neutron: The neutron client
    :param name: The expected router name
    :param exists: Whether or not the network name should exist or not
    :return: True/False
    """
    ports = neutron.list_ports()
    found = False
    for port, port_insts in ports.iteritems():
        for inst in port_insts:
            if inst.get('name') == name:
                found = True
    return exists == found
