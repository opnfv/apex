##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import json
import platform

import yaml

from apex.common import constants
from apex.common import utils


class Inventory(dict):
    """
    This class parses an APEX inventory yaml file into an object. It
    generates or detects all missing fields for deployment.

    It then collapses one level of identification from the object to
    convert it to a structure that can be dumped into a json file formatted
    such that Triple-O can read the resulting json as an instackenv.json file.
    """
    def __init__(self, source, ha=True, virtual=False):
        init_dict = {}
        self.root_device = constants.DEFAULT_ROOT_DEV
        if isinstance(source, str):
            with open(source, 'r') as inventory_file:
                yaml_dict = yaml.safe_load(inventory_file)
            # collapse node identifiers from the structure
            init_dict['nodes'] = list(map(lambda n: n[1],
                                          yaml_dict['nodes'].items()))
        else:
            # assume input is a dict to build from
            init_dict = source

        # move ipmi_* to pm_*
        # make mac a list
        def munge_nodes(node):
            node['pm_addr'] = node['ipmi_ip']
            node['pm_password'] = node['ipmi_pass']
            node['pm_user'] = node['ipmi_user']
            node['mac'] = [node['mac_address']]
            if 'cpus' in node:
                node['cpu'] = node['cpus']

            # aarch64 is always uefi
            if 'arch' in node and node['arch'] == 'aarch64':
                node['capabilities'] += ',boot_mode:uefi'

            for i in ('ipmi_ip', 'ipmi_pass', 'ipmi_user', 'mac_address',
                      'disk_device'):
                if i == 'disk_device' and 'disk_device' in node.keys():
                    self.root_device = node[i]
                else:
                    continue
                del node[i]

            return node

        super().__init__({'nodes': list(map(munge_nodes, init_dict['nodes']))})

        # verify number of nodes
        if ha and len(self['nodes']) < 5 and not virtual:
            raise InventoryException('You must provide at least 5 '
                                     'nodes for HA baremetal deployment')
        elif len(self['nodes']) < 2:
            raise InventoryException('You must provide at least 2 nodes '
                                     'for non-HA baremetal deployment')

        if virtual:
            self['host-ip'] = '192.168.122.1'
            self['power_manager'] = \
                'nova.virt.baremetal.virtual_power_driver.VirtualPowerManager'
            self['seed-ip'] = ''
            self['ssh-key'] = 'INSERT_STACK_USER_PRIV_KEY'
            self['ssh-user'] = 'root'

    def dump_instackenv_json(self):
        print(json.dumps(dict(self), sort_keys=True, indent=4))


class InventoryException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
            return self.value
