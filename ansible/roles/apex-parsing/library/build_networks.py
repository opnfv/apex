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

def make_quickstart_networks(apex_networks):
    result = []
    for network in apex_networks:
        result.append({ 'name' : network,
                        'virtualport_type' : 'openvswitch',
                        'bridge' : 'br-'+network,
                        'forward_mode' : 'bridge'
                      })

    return {'networks': result}
    
  

def main():
    module = AnsibleModule (
        argument_spec=dict(
            apex_networks=dict(required=True, type='dict'),
        )
    )

    networks = make_quickstart_networks(module.params["apex_networks"])
    module.exit_json(**networks)

from ansible.module_utils.basic import AnsibleModule
if __name__ == '__main__':
    main()
