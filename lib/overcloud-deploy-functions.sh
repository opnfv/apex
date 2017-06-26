#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

##preping it for deployment and launch the deploy
##params: none
function overcloud_deploy {

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source stackrc
set -o errexit
# Workaround for APEX-207 where sometimes swift proxy is down
if ! sudo systemctl status openstack-swift-proxy > /dev/null; then
  sudo systemctl restart openstack-swift-proxy
fi
echo "Uploading overcloud glance images"
openstack overcloud image upload

echo "Configuring undercloud and discovering nodes"


if [[ -z "$virtual" ]]; then
  openstack overcloud node import instackenv.json
  openstack overcloud node introspect --all-manageable --provide
  #if [[ -n "$root_disk_list" ]]; then
    # TODO: replace node configure boot with ironic node-update
    # TODO: configure boot is not used in ocata here anymore
    #openstack overcloud node configure boot --root-device=${root_disk_list}
    #https://github.com/openstack/tripleo-quickstart-extras/blob/master/roles/overcloud-prep-images/templates/overcloud-prep-images.sh.j2#L73-L130
    #ironic node-update $ironic_node add properties/root_device='{"{{ node['key'] }}": "{{ node['value'] }}"}'
  #fi
else
  openstack overcloud node import --provide instackenv.json
fi

openstack flavor set --property "cpu_arch"="x86_64" baremetal
openstack flavor set --property "cpu_arch"="x86_64" control
openstack flavor set --property "cpu_arch"="x86_64" compute
echo "Configuring nameserver on ctlplane network"
dns_server_ext=''
for dns_server in ${dns_servers}; do
  dns_server_ext="\${dns_server_ext} --dns-nameserver \${dns_server}"
done
openstack subnet set ctlplane-subnet \${dns_server_ext}
sed -i '/CloudDomain:/c\  CloudDomain: '${domain_name} ${ENV_FILE}
echo "Executing overcloud deployment, this could run for an extended period without output."
sleep 60 #wait for Hypervisor stats to check-in to nova
# save deploy command so it can be used for debugging
cat > deploy_command << EOF
openstack overcloud deploy --templates $DEPLOY_OPTIONS --timeout 90
EOF
EOI

  if [ "$interactive" == "TRUE" ]; then
    if ! prompt_user "Overcloud Deployment"; then
      echo -e "${blue}INFO: User requests exit${reset}"
      exit 0
    fi
  fi

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source stackrc
openstack overcloud deploy --templates $DEPLOY_OPTIONS --timeout 90
if ! openstack stack list | grep CREATE_COMPLETE 1>/dev/null; then
  $(typeset -f debug_stack)
  debug_stack
  exit 1
fi
EOI

  # Configure DPDK and restart ovs agent after bringing up br-phy
  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI || (echo "DPDK config failed, exiting..."; exit 1)
source stackrc
set -o errexit
for node in \$(nova list | grep novacompute | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"); do
echo "Checking DPDK status and bringing up br-phy on \$node"
ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
set -o errexit
sudo dpdk-devbind -s
sudo ifup br-phy
if [[ -z "${deploy_options_array['sdn_controller']}" || "${deploy_options_array['sdn_controller']}" == 'False' ]]; then
  echo "Restarting openvswitch agent to pick up VXLAN tunneling"
  sudo systemctl restart neutron-openvswitch-agent
fi
EOF
done
EOI
  fi

  if [ "$debug" == 'TRUE' ]; then
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source overcloudrc
echo "Keystone Endpoint List:"
openstack endpoint list
echo "Keystone Service List"
openstack service list
EOI
  fi
}
