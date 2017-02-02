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

# This is only used for virtual deployment. Baremetal is done via
# the Apex inventory
def build_virtual_inventory(apex_deploy):
    result = []
    virtualbmc_port = 6230

    if apex_deploy['global_params']['ha_enabled']:
      control_nodes = [ 'control0', 'control1', 'control2' ]
      compute_nodes = [ 'compute0', 'compute1' ]
    else:
      control_nodes = [ 'control0' ]
      compute_nodes = [ 'compute0' ]

    for node in control_nodes:
        result.append({ 'name' : node,
                        'flavor' : 'control',
                        'virtualbmc_port' : virtualbmc_port
                      })
        virtualbmc_port += 1

    for node in compute_nodes:
        result.append({ 'name' : node,
                        'flavor' : 'compute',
                        'virtualbmc_port' : virtualbmc_port
                      })
        virtualbmc_port += 1

    return {'overcloud_nodes': result}
    
  

def main():
    module = AnsibleModule (
        argument_spec=dict(
            apex_deploy=dict(required=True, type='dict'),
        )
    )

    inventory = build_virtual_inventory(module.params["apex_deploy"])
    module.exit_json(**inventory)

from ansible.module_utils.basic import AnsibleModule
if __name__ == '__main__':
    main()
