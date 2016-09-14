##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

ADMIN_NETWORK = 'admin'
TENANT_NETWORK = 'tenant'
EXTERNAL_NETWORK = 'external'
STORAGE_NETWORK = 'storage'
API_NETWORK = 'api'
CONTROLLER = 'controller'
COMPUTE = 'compute'

OPNFV_NETWORK_TYPES = [ADMIN_NETWORK, TENANT_NETWORK, EXTERNAL_NETWORK,
                       STORAGE_NETWORK, API_NETWORK]
DNS_SERVERS = ["8.8.8.8", "8.8.4.4"]
COMPUTE = 'compute'
CONTROLLER = 'controller'
ROLES = [COMPUTE, CONTROLLER]
DOMAIN_NAME = 'localdomain.com'
COMPUTE_PRE = "OS::TripleO::ComputeExtraConfigPre"
CONTROLLER_PRE = "OS::TripleO::ControllerExtraConfigPre"
PRE_CONFIG_DIR = "/usr/share/openstack-tripleo-heat-templates/puppet/" \
                 "extraconfig/pre_deploy/"
