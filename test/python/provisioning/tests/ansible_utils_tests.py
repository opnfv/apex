import logging
import unittest
import os

import paramiko
from paramiko import SSHClient
from scp import SCPClient

from openstack import create_image
import openstack.create_instance as create_instance
import openstack.create_network as create_network
import openstack.neutron_utils as neutron_utils
import openstack.create_keypairs as create_keypairs
from openstack.tests import openstack_tests
from provisioning import ansible_utils

VM_BOOT_TIMEOUT = 600

# Initialize Logging
logging.basicConfig(level=logging.DEBUG)

os_creds = openstack_tests.get_credentials()
priv_net_config = openstack_tests.get_priv_net_config()
pub_net_config = openstack_tests.get_pub_net_config()

flavor = 'm1.medium'

ip_1 = '10.0.1.100'
ip_2 = '10.0.1.200'
vm_inst_name = 'test-openstack-vm-instance-1'
keypair_name = 'testKP'
keypair_pub_filepath = '/tmp/testKP.pub'
keypair_priv_filepath = '/tmp/testKP'


# noinspection PyPackageRequirements
class AnsibleProvisioningTests(unittest.TestCase):
    """
    Test for the CreateInstance class with two NIC/Ports, eth0 with floating IP and eth1 w/o
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

        floating_ip_conf = dict()
        # Create ports/NICs for instance
        self.ports = list()

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
        self.test_file_remote_path = '/home/centos/hello.txt'
        self.test_file_local_path = '/tmp/hello.txt'

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

        if os.path.isfile(self.test_file_local_path):
            os.remove(self.test_file_local_path)

    def test_apply_simple_playbook(self):
        """
        Tests application of an Ansible playbook that simply copies over a file:
        1. Have a ~/.ansible.cfg (or alternate means) to set host_key_checking = False
        2. Set the following environment variable in your executing shell: ANSIBLE_HOST_KEY_CHECKING=False
        Should this not be performed, the creation of the host ssh key will cause your ansible calls to fail.
        """
        priv_key = self.inst_creator.keypair_creator.keypair_settings.private_filepath
        ip = self.inst_creator.floating_ip.ip
        user = self.inst_creator.remote_user
        ansible_utils.apply_playbook('provisioning/tests/playbooks/simple_playbook.yml', [ip], user, priv_key)

        ssh = SSHClient()
        ssh.set_missing_host_key_policy(paramiko.MissingHostKeyPolicy())
        ssh.connect(ip, username=user, key_filename=priv_key)
        scp = SCPClient(ssh.get_transport())
        scp.get(self.test_file_remote_path, self.test_file_local_path)

        self.assertTrue(os.path.isfile(self.test_file_local_path))

        with open(self.test_file_local_path) as f:
            file_contents = f.readline()
            self.assertEquals('Hello World!', file_contents)

    def test_apply_template_playbook(self):
        """
        Tests application of an Ansible playbook that applies a template to a file:
        1. Have a ~/.ansible.cfg (or alternate means) to set host_key_checking = False
        2. Set the following environment variable in your executing shell: ANSIBLE_HOST_KEY_CHECKING=False
        Should this not be performed, the creation of the host ssh key will cause your ansible calls to fail.
        """
        priv_key = self.inst_creator.keypair_creator.keypair_settings.private_filepath
        ip = self.inst_creator.floating_ip.ip
        user = self.inst_creator.remote_user
        ansible_utils.apply_playbook('provisioning/tests/playbooks/template_playbook.yml', [ip], user, priv_key,
                                     variables={'name': 'Foo'})

        ssh = SSHClient()
        ssh.set_missing_host_key_policy(paramiko.MissingHostKeyPolicy())
        # ssh.load_host_keys(priv_key)
        ssh.connect(ip, username=user, key_filename=priv_key)
        scp = SCPClient(ssh.get_transport())
        scp.get(self.test_file_remote_path, self.test_file_local_path)

        self.assertTrue(os.path.isfile(self.test_file_local_path))

        with open(self.test_file_local_path) as f:
            file_contents = f.readline()
            self.assertEquals('Hello Foo!', file_contents)
