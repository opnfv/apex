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
        def munge_node(node):
            pairs = (('pm_addr', 'ipmi_ip'), ('pm_password', 'ipmi_pass'),
                     ('pm_user', 'ipmi_user'), ('mac', 'mac_address'),
                     ('cpu', 'cpus'), (None, 'disk_device'))

            for x, y in pairs:
                if y in node:
                    if y == 'disk_device':
                        self.root_device = node[y]
                    elif x == 'mac':
                        node[x] = [node[y]]
                    elif x is not None and y in node:
                        node[x] = node[y]
                    del node[y]

            # aarch64 is always uefi
            if 'arch' in node and node['arch'] == 'aarch64':
                node['capabilities'] += ',boot_mode:uefi'

            return node

        super().__init__({'nodes': list(map(munge_node, init_dict['nodes']))})

        # verify number of nodes
        if ha and len(self['nodes']) < 5:
            raise ApexInventoryException('You must provide at least 5 '
                                         'nodes for HA deployment')
        elif len(self['nodes']) < 1:
            raise ApexInventoryException('You must provide at least 1 node '
                                         'for non-HA deployment')

        if virtual:
            self['host-ip'] = '192.168.122.1'
            self['power_manager'] = \
                'nova.virt.baremetal.virtual_power_driver.VirtualPowerManager'
            self['seed-ip'] = ''
            self['ssh-key'] = 'INSERT_STACK_USER_PRIV_KEY'
            self['ssh-user'] = 'root'

    def dump_instackenv_json(self):
        print(json.dumps(dict(self), sort_keys=True, indent=4))

    def get_node_counts(self):
        """
        Return numbers of controller and compute nodes in inventory
        :param inventory: node inventory data structure
        :return: number of controller and compute nodes in inventory
        """
        nodes = self['nodes']
        num_control = 0
        num_compute = 0
        for node in nodes:
            if 'profile:control' in node['capabilities']:
                num_control += 1
            elif 'profile:compute' in node['capabilities']:
                num_compute += 1
            else:
                raise ApexInventoryException("Node missing capabilities "
                                             "key: {}".format(node))
        return num_control, num_compute


class ApexInventoryException(Exception):
    pass
