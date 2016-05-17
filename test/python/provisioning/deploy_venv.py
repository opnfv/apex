#!/usr/bin/python
#
# This script is responsible for deploying environments to OpenStack

import sys
import logging
import os

from openstack import os_credentials
from openstack import neutron_utils
from openstack import nova_utils
from provisioning import ansible_utils
import file_utils

logger = logging.getLogger('deploy_venv')


def get_os_credentials(os_conn_config):
    """
    Returns an object containing all of the information required to access OpenStack APIs
    :param os_conn_config: The configuration holding the credentials
    :return: an OSCreds instance
    """
    return os_credentials.OSCreds(os_conn_config.get('username'),
                                  os_conn_config.get('password'),
                                  os_conn_config.get('auth_url'),
                                  os_conn_config.get('tenant_name'),
                                  os_conn_config.get('http_proxy'))


def create_image(os_conn_config, image_config):
    """
    Creates an image in OpenStack if necessary
    :param image_config: The image configuration
    :return: A reference to the image creator object from which the image object can be accessed
    """
    from openstack.create_image import OpenStackImage
    image_creator = OpenStackImage(get_os_credentials(os_conn_config), image_config.get('image_user'),
                                   image_config.get('format'), image_config.get('download_url'),
                                   image_config.get('name'), image_config.get('local_download_path'))
    image_creator.create()
    return image_creator


def create_network(os_conn_config, network_config):
    """
    Creates a network on which the CMTSs can attach
    :param os_conn_config: The OpenStack credentials object
    :param network_config: The network configuration
    :return: A reference to the network creator objects for each network from which network elements such as the
             subnet, router, interface router, and network objects can be accessed.
    """
    # Check for OS for network existence
    # If exists return network instance data
    # Else, create network and return instance data
    from openstack.create_network import OpenStackNetwork
    from openstack.create_network import NetworkSettings
    from openstack.create_network import SubnetSettings
    from openstack.create_network import RouterSettings

    config = network_config['network']

    logger.info('Attempting to create network with name - ' + config.get('name'))

    # try:
    network_creator = OpenStackNetwork(get_os_credentials(os_conn_config),
                                       NetworkSettings(name=config.get('name')),
                                       SubnetSettings(config.get('subnet')),
                                       RouterSettings(config.get('router')))
    network_creator.create()
    logger.info('Created network ')
    return network_creator


def create_keypair(os_conn_config, keypair_config):
    """
    Creates a keypair that can be applied to an instance
    :param os_conn_config: The OpenStack credentials object
    :param keypair_config: The keypair configuration
    :return: A reference to the keypair creator object
    """
    from openstack.create_keypairs import OpenStackKeypair
    from openstack.create_keypairs import KeypairSettings

    keypair_creator = OpenStackKeypair(get_os_credentials(os_conn_config), KeypairSettings(keypair_config))
    keypair_creator.create()
    return keypair_creator


def create_vm_instance(os_conn_config, instance_config, image, network_dict, keypair_creator):
    """
    Creates a VM instance
    :param os_conn_config: The OpenStack credentials
    :param instance_config: The VM instance configuration
    :param image: The VM image
    :param network_dict: A dictionary of network objects returned by OpenStack where the key contains the network name.
    :param keypair_creator: The object responsible for creating the keypair associated with this VM instance.
    :return: A reference to the VM instance object
    """
    from openstack.create_network import PortSettings
    from openstack.create_instance import OpenStackVmInstance

    os_creds = get_os_credentials(os_conn_config)
    neutron = neutron_utils.neutron_client(os_creds)
    config = instance_config['instance']
    ports_config = config['ports']
    existing_ports = neutron.list_ports()['ports']
    ports = list()

    for port_config in ports_config:
        network_name = port_config['port']['network_name']
        port_name = port_config['port']['name']
        found = False
        for existing_port in existing_ports:
            if existing_port['name'] == port_name:
                existing_port_dict = {'port': existing_port}
                ports.append(existing_port_dict)
                found = True

        if not found:
            os_network_obj = network_dict.get(network_name)
            if os_network_obj:
                logger.info('Creating port [' + port_config['port']['name'] + '] for network name - ' + network_name)
                port_setting = PortSettings(port_config)
                ports.append(
                    neutron_utils.create_port(neutron, port_setting, os_network_obj.network, os_network_obj.subnet))
            else:
                logger.warn('Cannot create port as associated network name of [' + network_name + '] not configured.')
                raise Exception

    from openstack.create_image import OpenStackImage
    # TODO - need to configure in the image username
    image_creator = OpenStackImage(image=image, image_user='centos')
    vm_inst = OpenStackVmInstance(os_creds, config['name'], config['flavor'], image_creator, ports, config['sudo_user'],
                                  keypair_creator, config.get('floating_ip'))
    vm_inst.create()
    return vm_inst


def create_images(os_conn_config, images_config):
    """
    Returns a dictionary of images where the key is the image name and the value is the image object
    :param os_conn_config: The OpenStack connection credentials
    :param images_config: The list of image configurations
    :return: dictionary
    """
    if images_config:
        images = {}
        for image_config_dict in images_config:
            image_config = image_config_dict.get('image')
            if image_config and image_config.get('name'):
                images[image_config['name']] = create_image(os_conn_config, image_config)
        logger.info('Created configured images')
        return images
    return dict()


def create_networks(os_conn_config, network_confs):
    """
    Returns a dictionary of networks where the key is the network name and the value is the network object
    :param os_conn_config: The OpenStack connection credentials
    :param network_confs: The list of network configurations
    :return: dictionary
    """
    if network_confs:
        network_dict = {}
        if network_confs:
            for network_conf in network_confs:
                net_name = network_conf['network']['name']
                network_dict[net_name] = create_network(os_conn_config, network_conf)
        logger.info('Created configured networks')
        return network_dict
    return dict()


def create_keypairs(os_conn_config, keypair_confs):
    """
    Returns a dictionary of keypairs where the key is the keypair name and the value is the keypair object
    :param os_conn_config: The OpenStack connection credentials
    :param keypair_confs: The list of keypair configurations
    :return: dictionary
    """
    if keypair_confs:
        keypairs_dict = {}
        if keypair_confs:
            for keypair_dict in keypair_confs:
                keypair_config = keypair_dict['keypair']
                keypairs_dict[keypair_config['name']] = create_keypair(os_conn_config, keypair_config)
        logger.info('Created configured keypairs')
        return keypairs_dict
    return dict()


def create_instances(os_conn_config, instances_config, images, network_dict, keypairs_dict):
    """
    Returns a dictionary of instances where the key is the instance name and the value is the VM object
    :param os_conn_config: The OpenStack connection credentials
    :param instances_config: The list of VM instance configurations
    :param images: A dictionary of images that will probably be used to instantiate the VM instance
    :param network_dict: A dictionary of networks that will probably be used to instantiate the VM instance
    :param keypairs_dict: A dictionary of keypairs that will probably be used to instantiate the VM instance
    :return: dictionary
    """
    if instances_config:
        vm_dict = {}
        for instance_config in instances_config:
            instance = instance_config.get('instance')
            if instance:
                if images:
                    inst_image = images.get(instance.get('imageName')).image
                else:
                    nova = nova_utils.nova_client(os_credentials.OSCreds(os_conn_config.get('username'),
                                                                         os_conn_config.get('password'),
                                                                         os_conn_config.get('auth_url'),
                                                                         os_conn_config.get('tenant_name'),
                                                                         os_conn_config.get('http_proxy')))
                    inst_image = nova.images.find(name=instance.get('imageName'))
                if inst_image:
                    vm_dict[instance['name']] = create_vm_instance(os_conn_config, instance_config,
                                                                   inst_image, network_dict,
                                                                   keypairs_dict[instance['keypair_name']])

        logger.info('Created configured instances')
        return vm_dict
    return dict()


def apply_ansible_playbooks(ansible_configs, vm_dict):
    """
    Applies
    :param ansible_configs: a list of Ansible configurations
    :param vm_dict: the dictionary of newly instantiated VMs where the VM name is the key
    :return:
    """
    if ansible_configs:
        # Ensure all hosts are accepting SSH session requests
        for vm_inst in vm_dict.values():
            if not vm_inst.vm_ssh_active(block=True):
                return

        # Apply playbooks
        for ansible_config in ansible_configs:
            apply_ansible_playbook(ansible_config, vm_dict)


def apply_ansible_playbook(ansible_config, vm_dict):
    """
    Applies an Ansible configuration setting
    :param ansible_config: the configuration settings
    :param vm_dict: the dictionary of newly instantiated VMs where the VM name is the key
    :return:
    """
    if ansible_config:
        # FIXME - Grab the first VM instance as the credentials and username MUST be the same for all machines
        vm = vm_dict.itervalues().next()
        floating_ips = __get_floating_ips(ansible_config, vm_dict)
        if floating_ips:
            ansible_utils.apply_playbook(ansible_config['playbook_location'], floating_ips, vm.remote_user,
                                         vm.keypair_creator.keypair_settings.private_filepath,
                                         variables=__get_variables(ansible_config.get('variables'), vm_dict))


def __get_floating_ips(ansible_config, vm_dict):
    """
    Returns a list of floating IP addresses
    :param ansible_config: the configuration settings
    :param vm_dict: the dictionary of VMs where the VM name is the key
    :return: list or None
    """
    if ansible_config.get('hosts'):
        hosts = ansible_config['hosts']
        if len(hosts) > 0:
            floating_ips = list()
            for host in hosts:
                vm = vm_dict.get(host)
                if vm:
                    floating_ips.append(vm.floating_ip.ip)
            return floating_ips
    return None


def __get_variables(var_config, vm_dict):
    """
    Returns a dictionary of substitution variables to be used for Ansible templates
    :param var_config: the variable configuration settings
    :param vm_dict: the dictionary of VMs where the VM name is the key
    :return: dictionary or None
    """
    if var_config and vm_dict and len(vm_dict) > 0:
        variables = dict()
        for key, value in var_config.iteritems():
            value = __get_variable_value(value, vm_dict)
            variables[key] = value
            logger.info("Set Jinga2 variable with key [" + key + "] the value [" + value + ']')
        return variables
    return None


def __get_variable_value(var_config_values, vm_dict):
    if var_config_values['type'] == 'string':
        return var_config_values['value']
    if var_config_values['type'] == 'os_creds':
        logger.info("Retrieving OS Credentials")
        vm = vm_dict.values()[0]
        if var_config_values['value'] == 'username':
            logger.info("Returning OS username")
            return vm.os_creds.username
        elif var_config_values['value'] == 'password':
            logger.info("Returning OS password")
            return vm.os_creds.password
        elif var_config_values['value'] == 'auth_url':
            logger.info("Returning OS auth_url")
            return vm.os_creds.auth_url
        elif var_config_values['value'] == 'tenant_name':
            logger.info("Returning OS tenant_name")
            return vm.os_creds.tenant_name

        logger.info("Returning none")
        return None
    if var_config_values['type'] == 'port':
        port_name = var_config_values.get('port_name')
        vm_name = var_config_values.get('vm_name')
        if port_name and vm_name:
            vm = vm_dict.get(vm_name)
            if vm:
                ports = vm.ports
                for port in ports:
                    if port['port']['name'] == port_name:
                        port_value_id = var_config_values.get('port_value')
                        if port_value_id:
                            if port_value_id == 'mac_address':
                                return port['port']['mac_address']
                            if port_value_id == 'ip_address':
                                # Currently only supporting the first IP assigned to a given port
                                return port['port']['dns_assignment'][0]['ip_address']
    return None


def main():
    """
    Will need to set environment variable ANSIBLE_HOST_KEY_CHECKING=False or ...
    Create a file located in /etc/ansible/ansible/cfg or ~/.ansible.cfg containing the following content:

    [defaults]
    host_key_checking = False

    CWD must be one directory up from where this script is located (SDN - name to be changed eventually).

    :return: To the OS
    """
    logging.basicConfig(level=logging.DEBUG)
    logger.info('Starting to Deploy')
    config = None
    if len(sys.argv) > 1:
        logger.info('Reading configuration')
        config = file_utils.read_yaml(sys.argv[1])

    if config:
        os_config = config.get('openstack')
        vm_dict = dict()
        if os_config:
            os_conn_config = os_config.get('connection')

            # Setup proxy settings if any
            if os_conn_config.get('http_proxy'):
                os.environ['HTTP_PROXY'] = os_conn_config['http_proxy']

            # Create images
            images = create_images(os_conn_config, os_config.get('images'))

            # Create network
            network_dict = create_networks(os_conn_config, os_config.get('networks'))

            # Create keypairs
            keypairs_dict = create_keypairs(os_conn_config, os_config.get('keypairs'))

            # Create instance
            # instances_config = os_config.get('instances')
            # instance_config = None
            vm_dict = create_instances(os_conn_config, os_config.get('instances'), images, network_dict, keypairs_dict)
            logger.info('Completed creating all configured instances')

            # TODO - Need to support other Linux flavors!
            logger.info('Configuring RPM NICs where required')
            for vm in vm_dict.itervalues():
                vm.config_rpm_nics()
            logger.info('Completed RPM NIC configuration')

        # Provision VMs
        ansible_config = config.get('ansible')
        if ansible_config and vm_dict:
            apply_ansible_playbooks(ansible_config, vm_dict)
    else:
        logger.error('Unable to read configuration file - ' + sys.argv[1])
        exit(1)
    exit(0)


if __name__ == '__main__':
    main()
