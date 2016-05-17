import unittest
import logging
import os

from Crypto.PublicKey import RSA

from openstack import create_keypairs
from openstack import nova_utils
from openstack.tests import openstack_tests

logging.basicConfig(level=logging.DEBUG)

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# To run these tests, the CWD must be set to the top level directory of this project
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

os_creds = openstack_tests.get_credentials()
keypair_name = 'create_kp_tests'

pub_file_path = 'tmp/create_kp_tests.pub'
priv_file_path = 'tmp/create_kp_tests'


class CreateKeypairsTests(unittest.TestCase):
    """
    Tests for the OpenStackKeypair class
    """

    def setUp(self):
        self.keypair_creator = None

    def tearDown(self):
        """
        Cleanup of created keypair
        """
        if self.keypair_creator:
            self.keypair_creator.clean()

        try:
            os.remove(pub_file_path)
        except:
            pass

        try:
            os.remove(priv_file_path)
        except:
            pass

    def test_create_keypair_only(self):
        """
        Tests the creation of a generated keypair without saving to file
        :return:
        """
        self.keypair_creator = create_keypairs.OpenStackKeypair(os_creds,
                                                                create_keypairs.KeypairSettings(name=keypair_name))
        self.keypair_creator.create()

        keypair = nova_utils.keypair_exists(self.keypair_creator.nova, self.keypair_creator.keypair)
        self.assertEquals(self.keypair_creator.keypair, keypair)

    def test_create_keypair_save_pub_only(self):
        """
        Tests the creation of a generated keypair and saves the public key only
        :return:
        """
        self.keypair_creator = create_keypairs.OpenStackKeypair(os_creds,
                                                        create_keypairs.KeypairSettings(name=keypair_name,
                                                                                        public_filepath=pub_file_path))
        self.keypair_creator.create()

        keypair = nova_utils.keypair_exists(self.keypair_creator.nova, self.keypair_creator.keypair)
        self.assertEquals(self.keypair_creator.keypair, keypair)

        file_key = open(os.path.expanduser(pub_file_path)).read()
        self.assertEquals(self.keypair_creator.keypair.public_key, file_key)

    def test_create_keypair_save_both(self):
        """
        Tests the creation of a generated keypair and saves both private and public key files[
        :return:
        """
        self.keypair_creator = create_keypairs.OpenStackKeypair(os_creds,
                                                    create_keypairs.KeypairSettings(name=keypair_name,
                                                                                    public_filepath=pub_file_path,
                                                                                    private_filepath=priv_file_path))
        self.keypair_creator.create()

        keypair = nova_utils.keypair_exists(self.keypair_creator.nova, self.keypair_creator.keypair)
        self.assertEquals(self.keypair_creator.keypair, keypair)

        file_key = open(os.path.expanduser(pub_file_path)).read()
        self.assertEquals(self.keypair_creator.keypair.public_key, file_key)

        self.assertTrue(os.path.isfile(priv_file_path))

    def test_create_keypair_from_file(self):
        """
        Tests the creation of an existing public keypair from a file
        :return:
        """
        keys = RSA.generate(1024)
        nova_utils.save_keys_to_files(keys=keys, pub_file_path=pub_file_path)
        self.keypair_creator = create_keypairs.OpenStackKeypair(os_creds,
                                                        create_keypairs.KeypairSettings(name=keypair_name,
                                                                                        public_filepath=pub_file_path))
        self.keypair_creator.create()

        keypair = nova_utils.keypair_exists(self.keypair_creator.nova, self.keypair_creator.keypair)
        self.assertEquals(self.keypair_creator.keypair, keypair)

        file_key = open(os.path.expanduser(pub_file_path)).read()
        self.assertEquals(self.keypair_creator.keypair.public_key, file_key)
