import os
import logging

import novaclient.v2.client as novaclient

logger = logging.getLogger('nova_utils')

"""
Utilities for basic OpenStack Nova API calls
"""


def nova_client(os_creds):
    """
    Instantiates and returns a client for communications with OpenStack's Nova server
    :param os_creds: The connection credentials to the OpenStack API
    :return: the client object
    """
    logger.info('Retrieving Nova Client')
    return novaclient.Client(**{
        'username': os_creds.username,
        'api_key': os_creds.password,
        'auth_url': os_creds.auth_url,
        'project_id': os_creds.tenant_name,
    })


def save_keys_to_files(keys=None, pub_file_path=None, priv_file_path=None):
    """
    Saves the generated RSA generated keys to the filesystem
    :param keys: the keys to save
    :param pub_file_path: the path to the public keys
    :param pub_file_path: the path to the private keys
    :return: None
    """
    if keys:
        if pub_file_path:
            pub_dir = os.path.dirname(pub_file_path)
            if not os.path.isdir(pub_dir):
                os.mkdir(pub_dir)
            public_handle = open(pub_file_path, 'wb')
            public_handle.write(keys.publickey().exportKey('OpenSSH'))
            public_handle.close()
            os.chmod(pub_file_path, 0400)
            logger.info("Saved public key to - " + pub_file_path)
        if priv_file_path:
            priv_dir = os.path.dirname(priv_file_path)
            if not os.path.isdir(priv_dir):
                os.mkdir(priv_dir)
            private_handle = open(priv_file_path, 'wb')
            private_handle.write(keys.exportKey())
            private_handle.close()
            os.chmod(priv_file_path, 0400)
            logger.info("Saved private key to - " + priv_file_path)


def upload_keypair_file(nova, name, file_path):
    """
    Uploads a public key from a file
    :param nova: the Nova client
    :param name: the keypair name
    :param file_path: the path to the public key file
    :return: the keypair object
    """
    with open(os.path.expanduser(file_path)) as fpubkey:
        logger.info('Saving keypair to - ' + file_path)
        return upload_keypair(nova, name, fpubkey.read())


def upload_keypair(nova, name, key):
    """
    Uploads a public key from a file
    :param nova: the Nova client
    :param name: the keypair name
    :param key: the public key object
    :return: the keypair object
    """
    logger.info('Creating keypair with name - ' + name)
    return nova.keypairs.create(name=name, public_key=key)


def keypair_exists(nova, keypair_obj):
    """
    Returns a copy of the keypair object if found
    :param nova: the Nova client
    :param keypair_obj: the keypair object
    :return: the keypair object or None if not found
    """
    try:
        return nova.keypairs.get(keypair_obj)
    except Exception as e:
        return None


def get_keypairs(nova):
    """
    Returns a list of all available keypairs
    :param nova: the Nova client
    :return: the list of objects
    """
    return nova.keypairs.list()


def delete_keypair(nova, key):
    """
    Deletes a keypair object from OpenStack
    :param nova: the Nova client
    :param key: the keypair object to delete
    """
    logger.debug('Deleting keypair - ' + key.name)
    nova.keypairs.delete(key)


def get_floating_ip_pools(nova):
    """
    Returns all of the available floating IP pools
    :param nova: the Nova client
    :return: a list of pools
    """
    return nova.floating_ip_pools.list()


def get_floating_ips(nova):
    """
    Returns all of the floating IPs
    :param nova: the Nova client
    :return: a list of floating IPs
    """
    return nova.floating_ips.list()


def create_floating_ip(nova, ext_net_name):
    """
    Returns the floating IP object that was created with this call
    :param nova: the Nova client
    :param ext_net_name: the name of the external network on which to apply the floating IP address
    :return: the floating IP object
    """
    logger.info('Creating floating ip to external network - ' + ext_net_name)
    return nova.floating_ips.create(ext_net_name)


def get_floating_ip(nova, floating_ip):
    """
    Returns a floating IP object that should be identical to the floating_ip parameter
    :param nova: the Nova client
    :param floating_ip: the floating IP object to lookup
    :return: hopefully the same floating IP object input
    """
    logger.debug('Attempting to retrieve existing floating ip with IP - ' + floating_ip.ip)
    return nova.floating_ips.get(floating_ip)


def delete_floating_ip(nova, floating_ip):
    """
    Responsible for deleting a floating IP
    :param nova: the Nova client
    :param floating_ip: the floating IP object to delete
    :return:
    """
    logger.debug('Attempting to delete existing floating ip with IP - ' + floating_ip.ip)
    return nova.floating_ips.delete(floating_ip)
