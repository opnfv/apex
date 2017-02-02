#!/usr/bin/python
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json

# Build baremetal inventory json string. This can be written out to a file
# and then passed to undercloud_instackenv_templates for use in the
# libvirt setup overcloud task
def build_baremetal_inventory(apex_inventory):
    result = {}
    disk_device = "sda"

    result['nodes'] = json.loads(json.dumps(apex_inventory['nodes']))


    for name, node in result['nodes'].items():
        node['pm_addr'] = node['ipmi_ip']
        node['pm_password'] = node['ipmi_pass']
        node['pm_user'] = node['ipmi_user']
        node['mac'] = [node['mac_address']]

        # disk device will still be in the apex_inventory for determining
        # root device
	for i in ('ipmi_ip', 'ipmi_pass', 'ipmi_user', 'mac_address',
		  'disk_device'):
            if i in node:
                if i == 'disk_device':
                    disk_device = node[i]
                del node[i]

    return {'apex_inventory_json': json.dumps(result),
            'root_disk_device' : disk_device}



def main():
    module = AnsibleModule (
        argument_spec=dict(
            apex_inventory=dict(required=True, type='dict'),
        )
    )

    inventory = build_baremetal_inventory(module.params["apex_inventory"])
    module.exit_json(**inventory)

from ansible.module_utils.basic import AnsibleModule
if __name__ == '__main__':
    main()
