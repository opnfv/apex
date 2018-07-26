#!/usr/bin/env python

##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import git
import json
import logging
import os
import platform
import pprint
import shutil
import sys
import tempfile
import yaml

import apex.virtual.configure_vm as vm_lib
import apex.virtual.utils as virt_utils
import apex.builders.common_builder as c_builder
import apex.builders.overcloud_builder as oc_builder
import apex.builders.undercloud_builder as uc_builder
from apex import DeploySettings
from apex import Inventory
from apex import NetworkEnvironment
from apex import NetworkSettings
from apex.common import utils
from apex.common import constants
from apex.common import parsers
from apex.common.exceptions import ApexDeployException
from apex.network import jumphost
from apex.network import network_data
from apex.undercloud import undercloud as uc_lib
from apex.overcloud import config as oc_cfg
from apex.overcloud import deploy as oc_deploy

APEX_TEMP_DIR = tempfile.mkdtemp(prefix='apex_tmp')
SDN_IMAGE = 'overcloud-full-opendaylight.qcow2'


def deploy_quickstart(args, deploy_settings_file, network_settings_file,
                      inventory_file=None):
    pass


def validate_cross_settings(deploy_settings, net_settings, inventory):
    """
    Used to validate compatibility across settings file.
    :param deploy_settings: parsed settings for deployment
    :param net_settings: parsed settings for network
    :param inventory: parsed inventory file
    :return: None
    """

    if deploy_settings['deploy_options']['dataplane'] != 'ovs' and 'tenant' \
            not in net_settings.enabled_network_list:
        raise ApexDeployException("Setting a DPDK based dataplane requires"
                                  "a dedicated NIC for tenant network")

    if 'odl_vpp_routing_node' in deploy_settings['deploy_options']:
        if deploy_settings['deploy_options']['dataplane'] != 'fdio':
            raise ApexDeployException("odl_vpp_routing_node should only be set"
                                      "when dataplane is set to fdio")
        if deploy_settings['deploy_options'].get('dvr') is True:
            raise ApexDeployException("odl_vpp_routing_node should only be set"
                                      "when dvr is not enabled")

    # TODO(trozet): add more checks here like RAM for ODL, etc
    # check if odl_vpp_netvirt is true and vpp is set
    # Check if fdio and nosdn:
    # tenant_nic_mapping_controller_members" ==
    # "$tenant_nic_mapping_compute_members


def build_vms(inventory, network_settings,
              template_dir='/usr/share/opnfv-apex'):
    """
    Creates VMs and configures vbmc and host
    :param inventory:
    :param network_settings:
    :return:
    """

    for idx, node in enumerate(inventory['nodes']):
        name = 'baremetal{}'.format(idx)
        volume = name + ".qcow2"
        volume_path = os.path.join(constants.LIBVIRT_VOLUME_PATH, volume)
        # TODO(trozet): add error checking
        vm_lib.create_vm(
            name, volume_path,
            baremetal_interfaces=network_settings.enabled_network_list,
            memory=node['memory'], cpus=node['cpu'],
            macs=node['mac'],
            template_dir=template_dir)
        virt_utils.host_setup({name: node['pm_port']})


def create_deploy_parser():
    deploy_parser = argparse.ArgumentParser()
    deploy_parser.add_argument('--debug', action='store_true', default=False,
                               help="Turn on debug messages")
    deploy_parser.add_argument('-l', '--log-file',
                               default='./apex_deploy.log',
                               dest='log_file', help="Log file to log to")
    deploy_parser.add_argument('-d', '--deploy-settings',
                               dest='deploy_settings_file',
                               required=True,
                               help='File which contains Apex deploy settings')
    deploy_parser.add_argument('-n', '--network-settings',
                               dest='network_settings_file',
                               required=True,
                               help='File which contains Apex network '
                                    'settings')
    deploy_parser.add_argument('-i', '--inventory-file',
                               dest='inventory_file',
                               default=None,
                               help='Inventory file which contains POD '
                                    'definition')
    deploy_parser.add_argument('-e', '--environment-file',
                               dest='env_file',
                               default='opnfv-environment.yaml',
                               help='Provide alternate base env file located '
                                    'in deploy_dir')
    deploy_parser.add_argument('-v', '--virtual', action='store_true',
                               default=False,
                               dest='virtual',
                               help='Enable virtual deployment')
    deploy_parser.add_argument('--interactive', action='store_true',
                               default=False,
                               help='Enable interactive deployment mode which '
                                    'requires user to confirm steps of '
                                    'deployment')
    deploy_parser.add_argument('--virtual-computes',
                               dest='virt_compute_nodes',
                               default=1,
                               type=int,
                               help='Number of Virtual Compute nodes to create'
                                    ' and use during deployment (defaults to 1'
                                    ' for noha and 2 for ha)')
    deploy_parser.add_argument('--virtual-cpus',
                               dest='virt_cpus',
                               default=4,
                               type=int,
                               help='Number of CPUs to use per Overcloud VM in'
                                    ' a virtual deployment (defaults to 4)')
    deploy_parser.add_argument('--virtual-default-ram',
                               dest='virt_default_ram',
                               default=8,
                               type=int,
                               help='Amount of default RAM to use per '
                                    'Overcloud VM in GB (defaults to 8).')
    deploy_parser.add_argument('--virtual-compute-ram',
                               dest='virt_compute_ram',
                               default=None,
                               type=int,
                               help='Amount of RAM to use per Overcloud '
                                    'Compute VM in GB (defaults to 8). '
                                    'Overrides --virtual-default-ram arg for '
                                    'computes')
    deploy_parser.add_argument('--deploy-dir',
                               default='/usr/share/opnfv-apex',
                               help='Directory to deploy from which contains '
                                    'base config files for deployment')
    deploy_parser.add_argument('--image-dir',
                               default='/var/opt/opnfv/images',
                               help='Directory which contains '
                                    'base disk images for deployment')
    deploy_parser.add_argument('--lib-dir',
                               default='/usr/share/opnfv-apex',
                               help='Directory path for apex ansible '
                                    'and third party libs')
    deploy_parser.add_argument('--quickstart', action='store_true',
                               default=False,
                               help='Use tripleo-quickstart to deploy')
    deploy_parser.add_argument('--upstream', action='store_true',
                               default=True,
                               help='Force deployment to use upstream '
                                    'artifacts. This option is now '
                                    'deprecated and only upstream '
                                    'deployments are supported.')
    deploy_parser.add_argument('--no-fetch', action='store_true',
                               default=False,
                               help='Ignore fetching latest upstream and '
                                    'use what is in cache')
    return deploy_parser


def validate_deploy_args(args):
    """
    Validates arguments for deploy
    :param args:
    :return: None
    """

    logging.debug('Validating arguments for deployment')
    if args.virtual and args.inventory_file is not None:
        logging.error("Virtual enabled but inventory file also given")
        raise ApexDeployException('You should not specify an inventory file '
                                  'with virtual deployments')
    elif args.virtual:
        args.inventory_file = os.path.join(APEX_TEMP_DIR,
                                           'inventory-virt.yaml')
    elif os.path.isfile(args.inventory_file) is False:
        logging.error("Specified inventory file does not exist: {}".format(
            args.inventory_file))
        raise ApexDeployException('Specified inventory file does not exist')

    for settings_file in (args.deploy_settings_file,
                          args.network_settings_file):
        if os.path.isfile(settings_file) is False:
            logging.error("Specified settings file does not "
                          "exist: {}".format(settings_file))
            raise ApexDeployException('Specified settings file does not '
                                      'exist: {}'.format(settings_file))


def main():
    parser = create_deploy_parser()
    args = parser.parse_args(sys.argv[1:])
    # FIXME (trozet): this is only needed as a workaround for CI.  Remove
    # when CI is changed
    if os.getenv('IMAGES', False):
        args.image_dir = os.getenv('IMAGES')
    if args.debug:
        log_level = logging.DEBUG
    else:
        log_level = logging.INFO
    os.makedirs(os.path.dirname(args.log_file), exist_ok=True)
    formatter = '%(asctime)s %(levelname)s: %(message)s'
    logging.basicConfig(filename=args.log_file,
                        format=formatter,
                        datefmt='%m/%d/%Y %I:%M:%S %p',
                        level=log_level)
    console = logging.StreamHandler()
    console.setLevel(log_level)
    console.setFormatter(logging.Formatter(formatter))
    logging.getLogger('').addHandler(console)
    utils.install_ansible()
    validate_deploy_args(args)
    # Parse all settings
    deploy_settings = DeploySettings(args.deploy_settings_file)
    logging.info("Deploy settings are:\n {}".format(pprint.pformat(
        deploy_settings)))
    net_settings = NetworkSettings(args.network_settings_file)
    logging.info("Network settings are:\n {}".format(pprint.pformat(
        net_settings)))
    os_version = deploy_settings['deploy_options']['os_version']
    net_env_file = os.path.join(args.deploy_dir, constants.NET_ENV_FILE)
    net_env = NetworkEnvironment(net_settings, net_env_file,
                                 os_version=os_version)
    net_env_target = os.path.join(APEX_TEMP_DIR, constants.NET_ENV_FILE)
    utils.dump_yaml(dict(net_env), net_env_target)

    # get global deploy params
    ha_enabled = deploy_settings['global_params']['ha_enabled']
    introspect = deploy_settings['global_params'].get('introspect', True)

    if args.virtual:
        if args.virt_compute_ram is None:
            compute_ram = args.virt_default_ram
        else:
            compute_ram = args.virt_compute_ram
        if deploy_settings['deploy_options']['sdn_controller'] == \
                'opendaylight' and args.virt_default_ram < 12:
            control_ram = 12
            logging.warning('RAM per controller is too low.  OpenDaylight '
                            'requires at least 12GB per controller.')
            logging.info('Increasing RAM per controller to 12GB')
        elif args.virt_default_ram < 10:
            control_ram = 10
            logging.warning('RAM per controller is too low.  nosdn '
                            'requires at least 10GB per controller.')
            logging.info('Increasing RAM per controller to 10GB')
        else:
            control_ram = args.virt_default_ram
        if ha_enabled and args.virt_compute_nodes < 2:
            logging.debug('HA enabled, bumping number of compute nodes to 2')
            args.virt_compute_nodes = 2
        virt_utils.generate_inventory(args.inventory_file, ha_enabled,
                                      num_computes=args.virt_compute_nodes,
                                      controller_ram=control_ram * 1024,
                                      compute_ram=compute_ram * 1024,
                                      vcpus=args.virt_cpus
                                      )
    inventory = Inventory(args.inventory_file, ha_enabled, args.virtual)

    validate_cross_settings(deploy_settings, net_settings, inventory)
    ds_opts = deploy_settings['deploy_options']
    if args.quickstart:
        deploy_settings_file = os.path.join(APEX_TEMP_DIR,
                                            'apex_deploy_settings.yaml')
        utils.dump_yaml(utils.dict_objects_to_str(deploy_settings),
                        deploy_settings_file)
        logging.info("File created: {}".format(deploy_settings_file))
        network_settings_file = os.path.join(APEX_TEMP_DIR,
                                             'apex_network_settings.yaml')
        utils.dump_yaml(utils.dict_objects_to_str(net_settings),
                        network_settings_file)
        logging.info("File created: {}".format(network_settings_file))
        deploy_quickstart(args, deploy_settings_file, network_settings_file,
                          args.inventory_file)
    else:
        # TODO (trozet): add logic back from:
        # Iedb75994d35b5dc1dd5d5ce1a57277c8f3729dfd (FDIO DVR)
        ansible_args = {
            'virsh_enabled_networks': net_settings.enabled_network_list
        }
        utils.run_ansible(ansible_args,
                          os.path.join(args.lib_dir, constants.ANSIBLE_PATH,
                                       'deploy_dependencies.yml'))
        uc_external = False
        if 'external' in net_settings.enabled_network_list:
            uc_external = True
        if args.virtual:
            # create all overcloud VMs
            build_vms(inventory, net_settings, args.deploy_dir)
        else:
            # Attach interfaces to jumphost for baremetal deployment
            jump_networks = ['admin']
            if uc_external:
                jump_networks.append('external')
            for network in jump_networks:
                if network == 'external':
                    # TODO(trozet): enable vlan secondary external networks
                    iface = net_settings['networks'][network][0][
                        'installer_vm']['members'][0]
                else:
                    iface = net_settings['networks'][network]['installer_vm'][
                        'members'][0]
                bridge = "br-{}".format(network)
                jumphost.attach_interface_to_ovs(bridge, iface, network)
        instackenv_json = os.path.join(APEX_TEMP_DIR, 'instackenv.json')
        with open(instackenv_json, 'w') as fh:
            json.dump(inventory, fh)

        # Create and configure undercloud
        if args.debug:
            root_pw = constants.DEBUG_OVERCLOUD_PW
        else:
            root_pw = None

        if not args.upstream:
            logging.warning("Using upstream is now required for Apex. "
                            "Forcing upstream to true")
        if os_version == 'master':
            branch = 'master'
        else:
            branch = "stable/{}".format(os_version)

        logging.info("Deploying with upstream artifacts for OpenStack "
                     "{}".format(os_version))
        args.image_dir = os.path.join(args.image_dir, os_version)
        upstream_url = constants.UPSTREAM_RDO.replace(
            constants.DEFAULT_OS_VERSION, os_version)
        upstream_targets = ['overcloud-full.tar', 'undercloud.qcow2']
        utils.fetch_upstream_and_unpack(args.image_dir, upstream_url,
                                        upstream_targets,
                                        fetch=not args.no_fetch)
        sdn_image = os.path.join(args.image_dir, 'overcloud-full.qcow2')
        # copy undercloud so we don't taint upstream fetch
        uc_image = os.path.join(args.image_dir, 'undercloud_mod.qcow2')
        uc_fetch_img = os.path.join(args.image_dir, 'undercloud.qcow2')
        shutil.copyfile(uc_fetch_img, uc_image)
        # prep undercloud with required packages
        uc_builder.add_upstream_packages(uc_image)
        # add patches from upstream to undercloud and overcloud
        logging.info('Adding patches to undercloud')
        patches = deploy_settings['global_params']['patches']
        c_builder.add_upstream_patches(patches['undercloud'], uc_image,
                                       APEX_TEMP_DIR, branch)

        # Create/Start Undercloud VM
        undercloud = uc_lib.Undercloud(args.image_dir,
                                       args.deploy_dir,
                                       root_pw=root_pw,
                                       external_network=uc_external,
                                       image_name=os.path.basename(uc_image),
                                       os_version=os_version)
        undercloud.start()
        undercloud_admin_ip = net_settings['networks'][
            constants.ADMIN_NETWORK]['installer_vm']['ip']

        if ds_opts['containers']:
            tag = constants.DOCKER_TAG
        else:
            tag = None

        # Generate nic templates
        for role in 'compute', 'controller':
            oc_cfg.create_nic_template(net_settings, deploy_settings, role,
                                       args.deploy_dir, APEX_TEMP_DIR)
        # Install Undercloud
        undercloud.configure(net_settings, deploy_settings,
                             os.path.join(args.lib_dir, constants.ANSIBLE_PATH,
                                          'configure_undercloud.yml'),
                             APEX_TEMP_DIR, virtual_oc=args.virtual)

        # Prepare overcloud-full.qcow2
        logging.info("Preparing Overcloud for deployment...")
        if os_version != 'ocata':
            net_data_file = os.path.join(APEX_TEMP_DIR, 'network_data.yaml')
            net_data = network_data.create_network_data(net_settings,
                                                        net_data_file)
        else:
            net_data = False

        # TODO(trozet): Either fix opnfv env or default to use upstream env
        if args.env_file == 'opnfv-environment.yaml':
            # Override the env_file if it is defaulted to opnfv
            # opnfv env file will not work with upstream
            args.env_file = 'upstream-environment.yaml'
        opnfv_env = os.path.join(args.deploy_dir, args.env_file)
        oc_deploy.prep_env(deploy_settings, net_settings, inventory,
                           opnfv_env, net_env_target, APEX_TEMP_DIR)
        if not args.virtual:
            oc_deploy.LOOP_DEVICE_SIZE = "50G"
        patched_containers = oc_deploy.prep_image(
            deploy_settings, net_settings, sdn_image, APEX_TEMP_DIR,
            root_pw=root_pw, docker_tag=tag, patches=patches['overcloud'])

        oc_deploy.create_deploy_cmd(deploy_settings, net_settings, inventory,
                                    APEX_TEMP_DIR, args.virtual,
                                    os.path.basename(opnfv_env),
                                    net_data=net_data)
        # Prepare undercloud with containers
        docker_playbook = os.path.join(args.lib_dir, constants.ANSIBLE_PATH,
                                       'prepare_overcloud_containers.yml')
        if ds_opts['containers']:
            ceph_version = constants.CEPH_VERSION_MAP[ds_opts['os_version']]
            ceph_docker_image = "ceph/daemon:tag-build-master-" \
                                "{}-centos-7".format(ceph_version)
            logging.info("Preparing Undercloud with Docker containers")
            if patched_containers:
                oc_builder.archive_docker_patches(APEX_TEMP_DIR)
            container_vars = dict()
            container_vars['apex_temp_dir'] = APEX_TEMP_DIR
            container_vars['patched_docker_services'] = list(
                patched_containers)
            container_vars['container_tag'] = constants.DOCKER_TAG
            container_vars['stackrc'] = 'source /home/stack/stackrc'
            container_vars['sdn'] = ds_opts['sdn_controller']
            container_vars['undercloud_ip'] = undercloud_admin_ip
            container_vars['os_version'] = os_version
            container_vars['ceph_docker_image'] = ceph_docker_image
            container_vars['sdn_env_file'] = \
                oc_deploy.get_docker_sdn_file(ds_opts)
            try:
                utils.run_ansible(container_vars, docker_playbook,
                                  host=undercloud.ip, user='stack',
                                  tmp_dir=APEX_TEMP_DIR)
                logging.info("Container preparation complete")
            except Exception:
                logging.error("Unable to complete container prep on "
                              "Undercloud")
                os.remove(os.path.join(APEX_TEMP_DIR, 'overcloud-full.qcow2'))
                raise

        deploy_playbook = os.path.join(args.lib_dir, constants.ANSIBLE_PATH,
                                       'deploy_overcloud.yml')
        virt_env = 'virtual-environment.yaml'
        bm_env = 'baremetal-environment.yaml'
        k8s_env = 'kubernetes-environment.yaml'
        for p_env in virt_env, bm_env, k8s_env:
            shutil.copyfile(os.path.join(args.deploy_dir, p_env),
                            os.path.join(APEX_TEMP_DIR, p_env))

        # Start Overcloud Deployment
        logging.info("Executing Overcloud Deployment...")
        deploy_vars = dict()
        deploy_vars['virtual'] = args.virtual
        deploy_vars['debug'] = args.debug
        deploy_vars['aarch64'] = platform.machine() == 'aarch64'
        deploy_vars['introspect'] = not (args.virtual or
                                         deploy_vars['aarch64'] or
                                         not introspect)
        deploy_vars['dns_server_args'] = ''
        deploy_vars['apex_temp_dir'] = APEX_TEMP_DIR
        deploy_vars['apex_env_file'] = os.path.basename(opnfv_env)
        deploy_vars['stackrc'] = 'source /home/stack/stackrc'
        deploy_vars['overcloudrc'] = 'source /home/stack/overcloudrc'
        deploy_vars['undercloud_ip'] = undercloud_admin_ip
        deploy_vars['ha_enabled'] = ha_enabled
        deploy_vars['os_version'] = os_version
        deploy_vars['http_proxy'] = net_settings.get('http_proxy', '')
        deploy_vars['https_proxy'] = net_settings.get('https_proxy', '')
        deploy_vars['vim'] = ds_opts['vim']
        for dns_server in net_settings['dns_servers']:
            deploy_vars['dns_server_args'] += " --dns-nameserver {}".format(
                dns_server)
        try:
            utils.run_ansible(deploy_vars, deploy_playbook, host=undercloud.ip,
                              user='stack', tmp_dir=APEX_TEMP_DIR)
            logging.info("Overcloud deployment complete")
        except Exception:
            logging.error("Deployment Failed.  Please check deploy log as "
                          "well as mistral logs in "
                          "{}".format(os.path.join(APEX_TEMP_DIR,
                                                   'mistral_logs.tar.gz')))
            raise
        finally:
            os.remove(os.path.join(APEX_TEMP_DIR, 'overcloud-full.qcow2'))

        # Post install
        logging.info("Executing post deploy configuration")
        jumphost.configure_bridges(net_settings)
        nova_output = os.path.join(APEX_TEMP_DIR, 'nova_output')
        deploy_vars['overcloud_nodes'] = parsers.parse_nova_output(
            nova_output)
        deploy_vars['SSH_OPTIONS'] = '-o StrictHostKeyChecking=no -o ' \
                                     'GlobalKnownHostsFile=/dev/null -o ' \
                                     'UserKnownHostsFile=/dev/null -o ' \
                                     'LogLevel=error'
        deploy_vars['external_network_cmds'] = \
            oc_deploy.external_network_cmds(net_settings, deploy_settings)
        # TODO(trozet): just parse all ds_opts as deploy vars one time
        deploy_vars['gluon'] = ds_opts['gluon']
        deploy_vars['sdn'] = ds_opts['sdn_controller']
        for dep_option in 'yardstick', 'dovetail', 'vsperf':
            if dep_option in ds_opts:
                deploy_vars[dep_option] = ds_opts[dep_option]
            else:
                deploy_vars[dep_option] = False
        deploy_vars['dataplane'] = ds_opts['dataplane']
        overcloudrc = os.path.join(APEX_TEMP_DIR, 'overcloudrc')
        if ds_opts['congress']:
            deploy_vars['congress_datasources'] = \
                oc_deploy.create_congress_cmds(overcloudrc)
            deploy_vars['congress'] = True
        else:
            deploy_vars['congress'] = False
        deploy_vars['calipso'] = ds_opts.get('calipso', False)
        deploy_vars['calipso_ip'] = undercloud_admin_ip
        # overcloudrc.v3 removed and set as default in queens and later
        if os_version == 'pike':
            deploy_vars['overcloudrc_files'] = ['overcloudrc',
                                                'overcloudrc.v3']
        else:
            deploy_vars['overcloudrc_files'] = ['overcloudrc']

        post_undercloud = os.path.join(args.lib_dir,
                                       constants.ANSIBLE_PATH,
                                       'post_deploy_undercloud.yml')
        logging.info("Executing post deploy configuration undercloud "
                     "playbook")
        try:
            utils.run_ansible(deploy_vars, post_undercloud,
                              host=undercloud.ip, user='stack',
                              tmp_dir=APEX_TEMP_DIR)
            logging.info("Post Deploy Undercloud Configuration Complete")
        except Exception:
            logging.error("Post Deploy Undercloud Configuration failed.  "
                          "Please check log")
            raise

        # Deploy kubernetes if enabled
        # (TODO)zshi move handling of kubernetes deployment
        # to its own deployment class
        if deploy_vars['vim'] == 'k8s':
            # clone kubespray repo
            git.Repo.clone_from(constants.KUBESPRAY_URL,
                                os.path.join(APEX_TEMP_DIR, 'kubespray'))
            shutil.copytree(
                os.path.join(APEX_TEMP_DIR, 'kubespray', 'inventory',
                             'sample'),
                os.path.join(APEX_TEMP_DIR, 'kubespray', 'inventory',
                             'apex'))
            k8s_node_inventory = {
                'all':
                    {'hosts': {},
                     'children': {
                         'k8s-cluster': {
                             'children': {
                                 'kube-master': {
                                     'hosts': {}
                                 },
                                 'kube-node': {
                                     'hosts': {}
                                 }
                             }
                         },
                         'etcd': {
                             'hosts': {}
                         }
                    }
                    }
            }
            for node, ip in deploy_vars['overcloud_nodes'].items():
                k8s_node_inventory['all']['hosts'][node] = {
                    'ansible_become': True,
                    'ansible_ssh_host': ip,
                    'ansible_become_user': 'root',
                    'ip': ip
                }
                if 'controller' in node:
                    k8s_node_inventory['all']['children']['k8s-cluster'][
                        'children']['kube-master']['hosts'][node] = None
                    k8s_node_inventory['all']['children']['etcd'][
                        'hosts'][node] = None
                elif 'compute' in node:
                    k8s_node_inventory['all']['children']['k8s-cluster'][
                        'children']['kube-node']['hosts'][node] = None

            kubespray_dir = os.path.join(APEX_TEMP_DIR, 'kubespray')
            with open(os.path.join(kubespray_dir, 'inventory', 'apex',
                                   'apex.yaml'), 'w') as invfile:
                yaml.dump(k8s_node_inventory, invfile,
                          default_flow_style=False)
            k8s_deploy_vars = {}
            # Add kubespray ansible control variables in k8s_deploy_vars,
            # example: 'kube_network_plugin': 'flannel'
            k8s_deploy = os.path.join(kubespray_dir, 'cluster.yml')
            k8s_deploy_inv_file = os.path.join(kubespray_dir, 'inventory',
                                               'apex', 'apex.yaml')

            k8s_remove_pkgs = os.path.join(args.lib_dir,
                                           constants.ANSIBLE_PATH,
                                           'k8s_remove_pkgs.yml')
            try:
                logging.debug("Removing any existing overcloud docker "
                              "packages")
                utils.run_ansible(k8s_deploy_vars, k8s_remove_pkgs,
                                  host=k8s_deploy_inv_file,
                                  user='heat-admin', tmp_dir=APEX_TEMP_DIR)
                logging.info("k8s Deploy Remove Existing Docker Related "
                             "Packages Complete")
            except Exception:
                logging.error("k8s Deploy Remove Existing Docker Related "
                              "Packages failed. Please check log")
                raise

            try:
                utils.run_ansible(k8s_deploy_vars, k8s_deploy,
                                  host=k8s_deploy_inv_file,
                                  user='heat-admin', tmp_dir=APEX_TEMP_DIR)
                logging.info("k8s Deploy Overcloud Configuration Complete")
            except Exception:
                logging.error("k8s Deploy Overcloud Configuration failed."
                              "Please check log")
                raise

        # Post deploy overcloud node configuration
        # TODO(trozet): just parse all ds_opts as deploy vars one time
        deploy_vars['sfc'] = ds_opts['sfc']
        deploy_vars['vpn'] = ds_opts['vpn']
        deploy_vars['l2gw'] = ds_opts.get('l2gw')
        deploy_vars['sriov'] = ds_opts.get('sriov')
        deploy_vars['tacker'] = ds_opts.get('tacker')
        # TODO(trozet): pull all logs and store in tmp dir in overcloud
        # playbook
        post_overcloud = os.path.join(args.lib_dir, constants.ANSIBLE_PATH,
                                      'post_deploy_overcloud.yml')
        # Run per overcloud node
        for node, ip in deploy_vars['overcloud_nodes'].items():
            logging.info("Executing Post deploy overcloud playbook on "
                         "node {}".format(node))
            try:
                utils.run_ansible(deploy_vars, post_overcloud, host=ip,
                                  user='heat-admin', tmp_dir=APEX_TEMP_DIR)
                logging.info("Post Deploy Overcloud Configuration Complete "
                             "for node {}".format(node))
            except Exception:
                logging.error("Post Deploy Overcloud Configuration failed "
                              "for node {}. Please check log".format(node))
                raise
        logging.info("Apex deployment complete")
        logging.info("Undercloud IP: {}, please connect by doing "
                     "'opnfv-util undercloud'".format(undercloud.ip))
        # TODO(trozet): add logging here showing controller VIP and horizon url


if __name__ == '__main__':
    main()
