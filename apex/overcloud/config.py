##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

"""
Utilities for generating overcloud configuration
"""

import logging
import os

from jinja2 import Environment
from jinja2 import FileSystemLoader
from apex.common.exceptions import ApexDeployException


def create_nic_template(network_settings, deploy_settings, role, template_dir,
                        target_dir):
    """
    Creates NIC heat template files
    :param ns: Network settings
    :param ds: Deploy Settings
    :param role: controller or compute
    :param template_dir: directory where base templates are stored
    :param target_dir: to store rendered nic template
    :return:
    """
    # TODO(trozet): rather than use Jinja2 to build these files, use with py
    if role not in ['controller', 'compute']:
        raise ApexDeployException("Invalid type for overcloud node: {"
                                  "}".format(type))
    logging.info("Creating template for {}".format(role))
    template_file = 'nics-template.yaml.jinja2'
    nets = network_settings.get('networks')
    env = Environment(loader=FileSystemLoader(template_dir), autoescape=True)
    template = env.get_template(template_file)
    ds = deploy_settings.get('deploy_options')
    ext_net = 'br-ex'
    ovs_dpdk_br = ''
    if ds['dataplane'] == 'fdio':
        nets['tenant']['nic_mapping'][role]['phys_type'] = 'vpp_interface'
        if ds['sdn_controller'] == 'opendaylight':
            if role == 'compute':
                nets['external'][0]['nic_mapping'][role]['phys_type'] = \
                    'vpp_interface'
                ext_net = 'vpp_interface'
            if ds.get('dvr') is True:
                nets['admin']['nic_mapping'][role]['phys_type'] = \
                    'linux_bridge'
        else:
            nets['external'][0]['nic_mapping'][role]['phys_type'] = \
                'linux_bridge'
    elif ds['dataplane'] == 'ovs_dpdk':
        ovs_dpdk_br = 'br-phy'
    if (ds.get('performance', {}).get(role.title(), {}).get('vpp', {})
            .get('uio-driver')):
        nets['tenant']['nic_mapping'][role]['uio-driver'] =\
            ds['performance'][role.title()]['vpp']['uio-driver']
        if ds['sdn_controller'] == 'opendaylight' and role == 'compute':
            nets['external'][0]['nic_mapping'][role]['uio-driver'] =\
                ds['performance'][role.title()]['vpp']['uio-driver']
    if (ds.get('performance', {}).get(role.title(), {}).get('vpp', {})
            .get('interface-options')):
        nets['tenant']['nic_mapping'][role]['interface-options'] =\
            ds['performance'][role.title()]['vpp']['interface-options']

    template_output = template.render(
        nets=nets,
        role=role,
        external_net_af=network_settings.get_ip_addr_family(),
        external_net_type=ext_net,
        ovs_dpdk_bridge=ovs_dpdk_br)

    logging.debug("Template output: {}".format(template_output))
    target = os.path.join(target_dir, "{}.yaml".format(role))
    with open(target, "w") as f:
        f.write(template_output)
    logging.info("Wrote template {}".format(target))
