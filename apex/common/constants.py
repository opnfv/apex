##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os

ADMIN_NETWORK = 'admin'
TENANT_NETWORK = 'tenant'
EXTERNAL_NETWORK = 'external'
STORAGE_NETWORK = 'storage'
API_NETWORK = 'api'
CONTROLLER = 'controller'
COMPUTE = 'compute'
ANSIBLE_PATH = 'ansible/playbooks'
OPNFV_NETWORK_TYPES = [ADMIN_NETWORK, TENANT_NETWORK, EXTERNAL_NETWORK,
                       STORAGE_NETWORK, API_NETWORK]
DNS_SERVERS = ["8.8.8.8", "8.8.4.4"]
NTP_SERVER = ["pool.ntp.org"]
COMPUTE = 'compute'
CONTROLLER = 'controller'
ROLES = [COMPUTE, CONTROLLER]
DOMAIN_NAME = 'localdomain.com'
COMPUTE_PRE = "OS::TripleO::ComputeExtraConfigPre"
CONTROLLER_PRE = "OS::TripleO::ControllerExtraConfigPre"
PRE_CONFIG_DIR = "/usr/share/openstack-tripleo-heat-templates/puppet/" \
                 "extraconfig/pre_deploy/"
DEFAULT_ROOT_DEV = 'sda'
LIBVIRT_VOLUME_PATH = '/var/lib/libvirt/images'

VIRT_UPLOAD = '--upload'
VIRT_INSTALL = '--install'
VIRT_RUN_CMD = '--run-command'
VIRT_PW = '--root-password'

THT_DIR = '/usr/share/openstack-tripleo-heat-templates'
THT_ENV_DIR = os.path.join(THT_DIR, 'environments')
THT_DOCKER_ENV_DIR = {
    'master': os.path.join(THT_ENV_DIR, 'services'),
    'queens': os.path.join(THT_ENV_DIR, 'services-docker')
}

DEFAULT_OS_VERSION = 'master'
DEFAULT_ODL_VERSION = 'oxygen'
VALID_ODL_VERSIONS = ['carbon', 'nitrogen', 'oxygen', 'master']
CEPH_VERSION_MAP = {'pike': 'jewel',
                    'queens': 'luminous',
                    'master': 'luminous'}
PUPPET_ODL_URL = 'https://git.opendaylight.org/gerrit/integration/packaging' \
                 '/puppet-opendaylight'
DEBUG_OVERCLOUD_PW = 'opnfvapex'
NET_ENV_FILE = 'network-environment.yaml'
DEPLOY_TIMEOUT = 90
UPSTREAM_RDO = 'https://images.rdoproject.org/master/delorean/current' \
               '-tripleo-rdo/'
OPENSTACK_GERRIT = 'https://review.openstack.org'

DOCKER_TAG = 'current-tripleo-rdo'
# Maps regular service files to docker versions
# None value means mapping is same as key
VALID_DOCKER_SERVICES = {
    'neutron-opendaylight.yaml': None,
    'neutron-opendaylight-dpdk.yaml': None,
    'neutron-opendaylight-sriov.yaml': None,
    'neutron-ml2-ovn.yaml': 'neutron-ovn.yaml'
}
DOCKERHUB_OOO = 'https://registry.hub.docker.com/v2/repositories' \
                '/tripleomaster/'
KUBESPRAY_URL = 'https://github.com/kubernetes-incubator/kubespray.git'
