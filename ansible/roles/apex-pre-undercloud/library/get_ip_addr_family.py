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
import netaddr

def get_ip_family(apex_networks):
    version = 4

    for network,details in apex_networks:
        if 'cidr' in details:
            nversion = netaddr.IPNetwork(details['cidr']).version
            if nversion > version:
                version = nversion
    return version 
    
  

def main():
    module = AnsibleModule (
        argument_spec=dict(
            apex_networks=dict(required=True, type='dict'),
        )
    )

    version = get_ip_family(module.params["apex_networks"])
    module.exit_json(changed=False, meta={version=version})

from ansible.module_utils.basic import AnsibleModule
if __name__ == '__main__':
    main()
