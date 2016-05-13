import logging
import unittest
import os

from openstack import create_image
from openstack import create_instance
from openstack import create_network
from openstack import neutron_utils
from openstack import create_keypairs
from openstack.tests import openstack_tests

VM_BOOT_TIMEOUT = 600

# Initialize Logging
logging.basicConfig(level=logging.DEBUG)

os_creds = openstack_tests.get_credentials()
priv_net_config = openstack_tests.get_priv_net_config()
pub_net_config = openstack_tests.get_pub_net_config()

flavor = 'm1.small'

ip_1 = '10.55.1.100'
ip_2 = '10.55.1.200'
vm_inst_name = 'test-openstack-vm-instance-1'
keypair_name = 'testKP'
keypair_pub_filepath = 'tmp/testKP.pub'
keypair_priv_filepath = 'tmp/testKP'


class CreateInstanceSingleNetworkTests(unittest.TestCase):
    """
    Test for the CreateInstance class with a single NIC/Port
    """

    def setUp(self):
        """
        Instantiates the CreateImage object that is responsible for downloading and creating an OS image file
        within OpenStack
        """
        # Create Image
        self.os_image_settings = openstack_tests.get_image_test_settings()
        self.image_creator = create_image.OpenStackImage(os_creds, self.os_image_settings.image_user,
                                                         self.os_image_settings.format, self.os_image_settings.url,
                                                         self.os_image_settings.name,
                                                         self.os_image_settings.download_file_path)
        self.image_creator.create()

        # Create Network
        self.network_creator = create_network.OpenStackNetwork(os_creds, pub_net_config.network_settings,
                                                               pub_net_config.subnet_settings,
                                                               pub_net_config.router_settings)
        self.network_creator.create()

        self.keypair_creator = create_keypairs.OpenStackKeypair(os_creds,
                                            create_keypairs.KeypairSettings(name=keypair_name,
                                                                            public_filepath=keypair_pub_filepath,
                                                                            private_filepath=keypair_priv_filepath))
        self.keypair_creator.create()

        self.ports = list()
        self.inst_creator = None

    def tearDown(self):
        """
        Cleans the created object
        """
        if self.inst_creator:
            self.inst_creator.clean()

        if self.keypair_creator:
            self.keypair_creator.clean()

        if os.path.isfile(keypair_pub_filepath):
            os.remove(keypair_pub_filepath)

        if os.path.isfile(keypair_priv_filepath):
            os.remove(keypair_priv_filepath)

        for port in self.ports:
            neutron_utils.delete_port(self.network_creator.neutron, port)

        if self.network_creator:
            self.network_creator.clean()

        if self.image_creator:
            self.image_creator.clean()

    def test_single_port_dhcp(self):
        """
        Tests the creation of an OpenStack instance with a single port with a DHCP assigned IP.
        """
        port_settings = create_network.PortSettings(name='test-port-1')
        self.ports.append(neutron_utils.create_port(self.network_creator.neutron, port_settings,
                                                    self.network_creator.network))
        self.inst_creator = create_instance.OpenStackVmInstance(os_creds, vm_inst_name, flavor,
                                                                self.image_creator, self.ports,
                                                                self.os_image_settings.image_user)
        vm_inst = self.inst_creator.create()

        self.assertTrue(self.inst_creator.vm_active(block=True))

        # TODO - add check to ensure can ssh with timout. Commented line below will almost always return False on the
        # first several attempts
        # self.assertTrue(self.inst_creator._ssh_active())
        self.assertEquals(vm_inst, self.inst_creator.vm)

    def test_single_port_static(self):
        """
        Tests the creation of an OpenStack instance with a single port with a static IP.
        """
        port_settings = create_network.PortSettings(name='test-port-1', ip_address=ip_1)
        self.ports.append(neutron_utils.create_port(self.network_creator.neutron, port_settings,
                                                    self.network_creator.network))
        floating_ip_conf = {'port_name': 'test-port-1', 'ext_net': pub_net_config.router_settings.external_gateway}
        self.inst_creator = create_instance.OpenStackVmInstance(os_creds, vm_inst_name, flavor,
                                                                self.image_creator, self.ports,
                                                                self.os_image_settings.image_user,
                                                                floating_ip_conf=floating_ip_conf)
        vm_inst = self.inst_creator.create()

        self.assertEquals(ip_1, self.inst_creator.ports[0]['port']['dns_assignment'][0]['ip_address'])
        self.assertTrue(self.inst_creator.vm_active(block=True))

        # TODO - add check to ensure can ssh with timout. Commented line below will almost always return False on the
        # first several attempts
        # self.assertTrue(self.inst_creator._ssh_active())
        self.assertEquals(vm_inst, self.inst_creator.vm)


class CreateInstancePubPrivNetTests(unittest.TestCase):
    """
    Test for the CreateInstance class with two NIC/Ports, eth0 with floating IP and eth1 w/o
    These tests require a Centos image and will fail on OS installations that cannot fire-up m1.medium VM instances
    """

    def setUp(self):
        """
        Instantiates the CreateImage object that is responsible for downloading and creating an OS image file
        within OpenStack
        """
        # Create Image
        self.os_image_settings = openstack_tests.get_instance_image_settings()
        self.image_creator = create_image.OpenStackImage(os_creds, self.os_image_settings.image_user,
                                                         self.os_image_settings.format,
                                                         self.os_image_settings.url,
                                                         self.os_image_settings.name,
                                                         self.os_image_settings.download_file_path)
        self.image_creator.create()

        # Create Network
        self.network_creators = list()
        # First network is public
        self.network_creators.append(create_network.OpenStackNetwork(os_creds, pub_net_config.network_settings,
                                                                     pub_net_config.subnet_settings,
                                                                     pub_net_config.router_settings))
        # Second network is private
        self.network_creators.append(create_network.OpenStackNetwork(os_creds, priv_net_config.network_settings,
                                                                     priv_net_config.subnet_settings,
                                                                     priv_net_config.router_settings))
        for network_creator in self.network_creators:
            network_creator.create()

        self.keypair_creator = create_keypairs.OpenStackKeypair(os_creds,
                                                create_keypairs.KeypairSettings(name=keypair_name,
                                                                                public_filepath=keypair_pub_filepath,
                                                                                private_filepath=keypair_priv_filepath))
        self.keypair_creator.create()

        self.ports = list()
        self.inst_creator = None

    def tearDown(self):
        """
        Cleans the created objects
        """
        if self.inst_creator:
            self.inst_creator.clean()

        if self.keypair_creator:
            self.keypair_creator.clean()

        if os.path.isfile(keypair_pub_filepath):
            os.remove(keypair_pub_filepath)

        if os.path.isfile(keypair_priv_filepath):
            os.remove(keypair_priv_filepath)

        for port in self.ports:
            neutron_utils.delete_port(self.network_creators[0].neutron, port)

        for network_creator in self.network_creators:
            network_creator.clean()

    def test_dual_ports_dhcp(self):
        """
        Tests the creation of an OpenStack instance with a dual ports/NICs with a DHCP assigned IP.
        NOTE: This test and any others that call ansible will most likely fail unless you do one of
        two things:
        1. Have a ~/.ansible.cfg (or alternate means) to set host_key_checking = False
        2. Set the following environment variable in your executing shell: ANSIBLE_HOST_KEY_CHECKING=False
        Should this not be performed, the creation of the host ssh key will cause your ansible calls to fail.
        """
        floating_ip_conf = dict()
        # Create ports/NICs for instance
        for network_creator in self.network_creators:
            idx = self.network_creators.index(network_creator)
            # port_name = 'test-port-' + `idx`
            port_name = 'test-port-' + repr(idx)
            if idx == 0:
                floating_ip_conf = {'port_name': port_name, 'ext_net': pub_net_config.router_settings.external_gateway}

            port_settings = create_network.PortSettings(name=port_name)
            self.ports.append(neutron_utils.create_port(network_creator.neutron, port_settings,
                                                        network_creator.network))

        # Create instance
        self.inst_creator = create_instance.OpenStackVmInstance(os_creds, vm_inst_name, flavor,
                                                                self.image_creator, self.ports,
                                                                self.os_image_settings.image_user,
                                                                keypair_creator=self.keypair_creator,
                                                                floating_ip_conf=floating_ip_conf)
        vm_inst = self.inst_creator.create()
        self.assertEquals(vm_inst, self.inst_creator.vm)

        # Effectively blocks until VM has been properly activated
        self.assertTrue(self.inst_creator.vm_active(block=True))

        # Effectively blocks until VM's ssh port has been opened
        self.assertTrue(self.inst_creator.vm_ssh_active(block=True))

        self.inst_creator.config_rpm_nics()
        # TODO - *** ADD VALIDATION HERE ***
