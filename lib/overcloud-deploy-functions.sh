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
}
