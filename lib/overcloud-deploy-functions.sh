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
  local num_compute_nodes
  local num_control_nodes
  local dpdk_cores pmd_cores socket_mem ovs_dpdk_perf_flag ovs_option_heat_arr
  declare -A ovs_option_heat_arr

  ovs_option_heat_arr['dpdk_cores']=OvsDpdkCoreList
  ovs_option_heat_arr['pmd_cores']=PmdCoreList
  ovs_option_heat_arr['socket_memory']=OvsDpdkSocketMemory

  # Patch neutron with using OVS external interface for router and add generic linux NS interface driver
  if [[ "${deploy_options_array['dataplane']}" == 'fdio' ]]; then
    # Configure routing node and interface role mapping for odl-fdio
    if [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' && "${deploy_options_array['odl_vpp_routing_node']}" != 'dvr' ]]; then
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
        sed -i "/opendaylight::vpp_routing_node:/c\    opendaylight::vpp_routing_node: ${deploy_options_array['odl_vpp_routing_node']}.${domain_name}" ${ENV_FILE}
        sed -i "/ControllerExtraConfig:/ c\  ControllerExtraConfig:\n    tripleo::profile::base::neutron::agents::honeycomb::interface_role_mapping:  ['${tenant_nic_mapping_controller_members}:tenant-interface']" ${ENV_FILE}
        sed -i "/NovaComputeExtraConfig:/ c\  NovaComputeExtraConfig:\n    tripleo::profile::base::neutron::agents::honeycomb::interface_role_mapping:  ['${tenant_nic_mapping_compute_members}:tenant-interface','${external_nic_mapping_compute_members}:public-interface']" ${ENV_FILE}
EOI
    fi
  fi

  if [ -n "${deploy_options_array['performance']}" ]; then
    ovs_dpdk_perf_flag="False"
    for option in "${performance_options[@]}" ; do
      if [ "${arr[1]}" == "vpp" ]; then
        if [ "${arr[0]}" == "Compute" ]; then
          role='NovaCompute'
        else
          role=${arr[0]}
        fi
        if [ "${arr[2]}" == "main-core" ]; then
          ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
            sed -i "/${role}ExtraConfig:/ c\  ${role}ExtraConfig:\n    fdio::vpp_cpu_main_core: '${arr[3]}'" ${ENV_FILE}
EOI
        elif [ "${arr[2]}" == "corelist-workers" ]; then
          ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
            sed -i "/${role}ExtraConfig:/ c\  ${role}ExtraConfig:\n    fdio::vpp_cpu_corelist_workers: '${arr[3]}'" ${ENV_FILE}
EOI
        fi
      fi
      arr=($option)
      # use compute's kernel settings for all nodes for now.
      if [ "${arr[0]}" == "Compute" ] && [ "${arr[1]}" == "kernel" ]; then
        kernel_args+=" ${arr[2]}=${arr[3]}"
      fi
      if [ "${arr[0]}" == "Compute" ] && [ "${arr[1]}" == "ovs" ]; then
         eval "${arr[2]}=${arr[3]}"
         ovs_dpdk_perf_flag="True"
      fi
    done

    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      sed -i "/ComputeKernelArgs:/c\  ComputeKernelArgs: '$kernel_args'" ${ENV_FILE}
      sed -i "$ a\resource_registry:\n  OS::TripleO::NodeUserData: first-boot.yaml" ${ENV_FILE}
      sed -i "/NovaSchedulerDefaultFilters:/c\  NovaSchedulerDefaultFilters: 'RamFilter,ComputeFilter,AvailabilityZoneFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,NUMATopologyFilter'" ${ENV_FILE}
EOI

    if [[ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' && "$ovs_dpdk_perf_flag" == "True" ]]; then
      for ovs_option in ${!ovs_option_heat_arr[@]}; do
        if [ -n "${!ovs_option}" ]; then
          ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
            sed -i "/${ovs_option_heat_arr[$ovs_option]}:/c\  ${ovs_option_heat_arr[$ovs_option]}: ${!ovs_option}" ${ENV_FILE}
EOI
        fi
      done
    fi
  fi

  if [[ -z "${deploy_options_array['sdn_controller']}" || "${deploy_options_array['sdn_controller']}" == 'False' ]]; then
    if [ "${deploy_options_array['dataplane']}" == "fdio" ]; then
      if [ "$tenant_nic_mapping_controller_members" == "$tenant_nic_mapping_compute_members" ]; then
        echo -e "${blue}INFO: nosdn fdio deployment...installing correct vpp packages...${reset}"
        ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
          sed -i "/NeutronVPPAgentPhysnets:/c\  NeutronVPPAgentPhysnets: 'datacentre:${tenant_nic_mapping_controller_members}'" ${ENV_FILE}
EOI
      else
        echo -e "${red}Compute and Controller must use the same tenant nic name, please modify network setting file.${reset}"
        exit 1
      fi
    fi
  fi

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
# Create a key for use by nova for live migration
echo "Creating nova SSH key for nova resize support"
ssh-keygen -f nova_id_rsa -b 1024 -P ""
public_key=\'\$(cat nova_id_rsa.pub | cut -d ' ' -f 2)\'
sed -i "s#replace_public_key:#key: \$public_key#g" ${ENV_FILE}
python -c 'open("opnfv-environment-new.yaml", "w").write((open("${ENV_FILE}").read().replace("replace_private_key:", "key: \"" + "".join(open("nova_id_rsa").readlines()).replace("\\n","\\\n") + "\"")))'
mv -f opnfv-environment-new.yaml ${ENV_FILE}

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
