import unittest
import logging

from openstack import create_network
from openstack.tests import neutron_utils_tests
from openstack.tests import openstack_tests


# Initialize Logging
logging.basicConfig(level=logging.DEBUG)

os_creds = openstack_tests.get_credentials()

net_config = openstack_tests.get_pub_net_config()


class CreateNetworkSuccessTests(unittest.TestCase):
    """
    Test for the CreateImage class defined in create_image.py
    """

    def setUp(self):
        """
        Instantiates the CreateImage object that is responsible for downloading and creating an OS image file
        within OpenStack
        """
        self.net_creator = create_network.OpenStackNetwork(os_creds, net_config.network_settings,
                                                           net_config.subnet_settings,
                                                           net_config.router_settings)

    def tearDown(self):
        """
        Cleans the image and downloaded image file
        """
        self.net_creator.clean()

        if self.net_creator.subnet:
            # Validate subnet has been deleted
            neutron_utils_tests.validate_subnet(self.net_creator.neutron, self.net_creator.subnet_settings.name,
                                                self.net_creator.subnet_settings.cidr, False)

        if self.net_creator.network:
            # Validate network has been deleted
            neutron_utils_tests.validate_network(self.net_creator.neutron, self.net_creator.network_settings.name,
                                                 False)

    def test_create_network(self):
        """
        Tests the creation of an OpenStack network.
        """
        # Create Image
        self.net_creator.create()

        # Validate network was created
        neutron_utils_tests.validate_network(self.net_creator.neutron, self.net_creator.network_settings.name, True)

        # Validate subnets
        neutron_utils_tests.validate_subnet(self.net_creator.neutron, self.net_creator.subnet_settings.name,
                                            self.net_creator.subnet_settings.cidr, True)

        # Validate routers
        neutron_utils_tests.validate_router(self.net_creator.neutron, self.net_creator.router_settings.name, True)

        # Validate interface routers
        neutron_utils_tests.validate_interface_router(self.net_creator.interface_router, self.net_creator.router,
                                                      self.net_creator.subnet)

        # TODO - Expand tests especially negative ones.
