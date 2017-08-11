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

  ovs_option_heat_arr['dpdk_cores']=HostCpusList
  ovs_option_heat_arr['pmd_cores']=NeutronDpdkCoreList
  ovs_option_heat_arr['socket_memory']=NeutronDpdkSocketMemory
  ovs_option_heat_arr['memory_channels']=NeutronDpdkMemoryChannels

  # OPNFV Default Environment and Network settings
  DEPLOY_OPTIONS+=" -e ${ENV_FILE}"
  DEPLOY_OPTIONS+=" -e network-environment.yaml"

  # get number of nodes available in inventory
  num_control_nodes=$(ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "grep -c profile:control /home/stack/instackenv.json")
  num_compute_nodes=$(ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "grep -c profile:compute /home/stack/instackenv.json")

  # Custom Deploy Environment Templates
  if [[ "${#deploy_options_array[@]}" -eq 0 || "${deploy_options_array['sdn_controller']}" == 'opendaylight' ]]; then
    if [ "${deploy_options_array['sfc']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-sfc-opendaylight.yaml"
    elif [ "${deploy_options_array['vpn']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-bgpvpn-opendaylight.yaml"
      if [ "${deploy_options_array['gluon']}" == 'True' ]; then
        DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/gluon.yaml"
      fi
    elif [ "${deploy_options_array['vpp']}" == 'True' ]; then
      if [ "${deploy_options_array['odl_vpp_netvirt']}" == "True" ]; then
        DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight-netvirt-vpp.yaml"
      elif [ "${deploy_options_array['odl_vpp_routing_node']}" == "dvr" ]; then
        DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight-fdio-dvr.yaml"
      else
        DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight-honeycomb.yaml"
      fi
    else
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight.yaml"
    fi
    SDN_IMAGE=opendaylight
  elif [ "${deploy_options_array['sdn_controller']}" == 'opendaylight-external' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight-external.yaml"
    SDN_IMAGE=opendaylight
  elif [ "${deploy_options_array['sdn_controller']}" == 'onos' ]; then
    if [ "${deploy_options_array['sfc']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-onos-sfc.yaml"
    else
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-onos.yaml"
    fi
    SDN_IMAGE=onos
  elif [ "${deploy_options_array['sdn_controller']}" == 'ovn' ]; then
    if [[ "$ha_enabled" == "True" ]]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-ml2-ovn-ha.yaml"
      echo "${red}OVN HA support is not not supported... exiting.${reset}"
      exit 1
    else
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-ml2-ovn.yaml"
    fi
    SDN_IMAGE=opendaylight
  elif [ "${deploy_options_array['sdn_controller']}" == 'opencontrail' ]; then
    echo -e "${red}ERROR: OpenContrail is currently unsupported...exiting${reset}"
    exit 1
  elif [[ -z "${deploy_options_array['sdn_controller']}" || "${deploy_options_array['sdn_controller']}" == 'False' ]]; then
    echo -e "${blue}INFO: SDN Controller disabled...will deploy nosdn scenario${reset}"
    if [ "${deploy_options_array['vpp']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-ml2-vpp.yaml"
    elif [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-ovs-dpdk.yaml"
    fi
    SDN_IMAGE=opendaylight
  else
    echo "${red}Invalid sdn_controller: ${deploy_options_array['sdn_controller']}${reset}"
    echo "${red}Valid choices are opendaylight, opendaylight-external, onos, opencontrail, False, or null${reset}"
    exit 1
  fi

  # Enable Tacker
  if [ "${deploy_options_array['tacker']}" == 'True' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/enable_tacker.yaml"
  fi

  # Enable Congress
  if [ "${deploy_options_array['congress']}" == 'True' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/enable_congress.yaml"
  fi

  # Enable Real Time Kernel (kvm4nfv)
  if [ "${deploy_options_array['rt_kvm']}" == 'True' ]; then
    DEPLOY_OPTIONS+=" -e /home/stack/enable_rt_kvm.yaml"
  fi

  # Enable Barometer service
  if [ "${deploy_options_array['barometer']}" == 'True' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/enable_barometer.yaml"
  fi

# Make sure the correct overcloud image is available
  if [ ! -f $IMAGES/overcloud-full-${SDN_IMAGE}.qcow2 ]; then
      echo "${red} $IMAGES/overcloud-full-${SDN_IMAGE}.qcow2 is required to execute your deployment."
      echo "Please install the opnfv-apex package to provide this overcloud image for deployment.${reset}"
      exit 1
  fi

  echo "Copying overcloud image to Undercloud"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "rm -f overcloud-full.qcow2"
  scp ${SSH_OPTIONS[@]} $IMAGES/overcloud-full-${SDN_IMAGE}.qcow2 "stack@$UNDERCLOUD":overcloud-full.qcow2

  # disable neutron openvswitch agent from starting
  if [[ -n "${deploy_options_array['sdn_controller']}" && "${deploy_options_array['sdn_controller']}" != 'False' ]]; then
      echo -e "${blue}INFO: Disabling neutron-openvswitch-agent from systemd${reset}"
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize --run-command "rm -f /etc/systemd/system/multi-user.target.wants/neutron-openvswitch-agent.service" \
                                               --run-command "rm -f /usr/lib/systemd/system/neutron-openvswitch-agent.service" \
                                               -a overcloud-full.qcow2
EOI
  fi

  if [ "${deploy_options_array['vpn']}" == 'True' ]; then
      echo -e "${blue}INFO: Enabling ZRPC and Quagga${reset}"
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize \
         --run-command "systemctl enable zrpcd" \
         -a overcloud-full.qcow2
EOI
  fi

  # Install ovs-dpdk inside the overcloud image if it is enabled.
  if [[ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' || "${deploy_options_array['dataplane']}" == 'fdio' ]]; then
    # install dpdk packages before ovs
    echo -e "${blue}INFO: Enabling kernel modules for dpdk inside overcloud image${reset}"

    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      cat << EOF > vfio_pci.modules
#!/bin/bash
exec /sbin/modprobe vfio_pci >/dev/null 2>&1
EOF

      cat << EOF > uio_pci_generic.modules
#!/bin/bash
exec /sbin/modprobe uio_pci_generic >/dev/null 2>&1
EOF

      LIBGUESTFS_BACKEND=direct virt-customize --upload vfio_pci.modules:/etc/sysconfig/modules/ \
                                               --upload uio_pci_generic.modules:/etc/sysconfig/modules/ \
                                               --run-command "chmod 0755 /etc/sysconfig/modules/vfio_pci.modules" \
                                               --run-command "chmod 0755 /etc/sysconfig/modules/uio_pci_generic.modules" \
                                               -a overcloud-full.qcow2

      if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
        sed -i "/OS::TripleO::ComputeExtraConfigPre:/c\  OS::TripleO::ComputeExtraConfigPre: ./ovs-dpdk-preconfig.yaml" network-environment.yaml
      fi

EOI

  elif [ "${deploy_options_array['dataplane']}" != 'ovs' ]; then
    echo "${red}${deploy_options_array['dataplane']} not supported${reset}"
    exit 1
  fi

  if [ "$debug" == 'TRUE' ]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "LIBGUESTFS_BACKEND=direct virt-customize -a overcloud-full.qcow2 --root-password password:opnfvapex"
  fi

  # upgrade ovs into ovs ovs 2.6.1 with NSH function if SFC is enabled
  if [[ "${deploy_options_array['sfc']}" == 'True' && "${deploy_options_array['dataplane']}" == 'ovs' ]]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
         LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum install -y /root/ovs/rpm/rpmbuild/RPMS/x86_64/${ovs_kmod_rpm_name}" \
                                                  --run-command "yum upgrade -y /root/ovs/rpm/rpmbuild/RPMS/x86_64/${ovs_rpm_name}" \
                                                  -a overcloud-full.qcow2
EOI
  fi

  # Patch neutron with using OVS external interface for router and add generic linux NS interface driver
  if [[ "${deploy_options_array['dataplane']}" == 'fdio' ]]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize --run-command "cd /usr/lib/python2.7/site-packages/ && patch -p1 < neutron-patch-NSDriver.patch" \
                                               -a overcloud-full.qcow2
EOI

    # Configure routing node for odl-fdio
    if [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' ]]; then
      if [[ "${deploy_options_array['odl_vpp_routing_node']}" == 'dvr' ]]; then
        ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
          sed -i "/OS::TripleO::Services::NeutronDhcpAgent/d" ${ENV_FILE}
          sed -i "/NeutronDhcpAgentsPerNetwork:/ c\  NeutronDhcpAgentsPerNetwork: $num_compute_nodes" ${ENV_FILE}
          sed -i "$ a\    - OS::TripleO::Services::NeutronDhcpAgent" ${ENV_FILE}
# TODO: Update VPP version to 17.10 when specific version is known
#          LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum remove -y vpp-lib" \
#                                                   --run-command "yum install -y /root/fdio_dvr/*.rpm" \
#                                                   --run-command "rm -f /etc/sysctl.d/80-vpp.conf" \
#                                                   -a overcloud-full.qcow2
EOI
      else
        ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
          sed -i "/opendaylight::vpp_routing_node:/c\    opendaylight::vpp_routing_node: ${deploy_options_array['odl_vpp_routing_node']}.${domain_name}" ${ENV_FILE}
EOI
      fi
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
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
            sed -i "/${ovs_option_heat_arr[$ovs_option]}:/c\  ${ovs_option_heat_arr[$ovs_option]}: '${!ovs_option}'" ${ENV_FILE}
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

  # Set ODL version accordingly
  if [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' && -n "${deploy_options_array['odl_version']}" ]]; then
    case "${deploy_options_array['odl_version']}" in
      carbon) odl_version=''
              ;;
      *) echo -e "${red}Invalid ODL version ${deploy_options_array['odl_version']}.  Please use 'carbon'.${reset}"
         exit 1
         ;;
    esac

    if [[  -n "$odl_version" ]]; then
        ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
          LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum -y remove opendaylight" \
                                                   --run-command "yum -y install /root/${odl_version}/*" \
                                                   -a overcloud-full.qcow2
EOI
    fi

    # Overwrite puppet-opendaylight with carbon. By default we install boron branch.
    if [ "${deploy_options_array['odl_version']}" == 'carbon' ]; then
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
        LIBGUESTFS_BACKEND=direct virt-customize --run-command "rm -rf /etc/puppet/modules/opendaylight" \
                                                 --run-command "cd /etc/puppet/modules/ && tar xzf /root/puppet-opendaylight-carbon.tar.gz" \
                                                 -a overcloud-full.qcow2
EOI
    fi
  fi

  # Override ODL for fdio scenarios
  if [[ "${deploy_options_array['odl_vpp_netvirt']}" == 'True' && "${deploy_options_array['sdn_controller']}" == 'opendaylight' ]]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum -y remove opendaylight" \
                                               --run-command "yum -y install /root/opendaylight-7.0.0-0.1.20170531snap665.el7.noarch.rpm" \
                                               -a overcloud-full.qcow2
EOI
#  elif [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' && "${deploy_options_array['dataplane']}" == 'fdio' ]]; then
#    if [[ "${deploy_options_array['odl_vpp_routing_node']}" != 'dvr' ]]; then
#      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
#        LIBGUESTFS_BACKEND=direct virt-customize --run-command "rm -rf /opt/opendaylight/*" \
#                                                 --run-command "tar zxvf /root/fdio_odl_carbon.tar.gz -C /opt/opendaylight/ --strip-components=1" \
#                                                 --run-command "chown odl:odl -R /opt/opendaylight" \
#                                                 -a overcloud-full.qcow2
#EOI
#    fi
  fi

  # Override ODL if we enable dvr for fdio
# TODO: Update ODL version when specific version is known.
#  if [[ "${deploy_options_array['odl_vpp_routing_node']}" == 'dvr' ]]; then
#    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
#      LIBGUESTFS_BACKEND=direct virt-customize --run-command "rm -rf /opt/opendaylight/*" \
#                                               --run-command "tar zxvf /root/fdio_odl_carbon.tar.gz -C /opt/opendaylight/ --strip-components=1" \
#                                               --run-command "chown odl:odl -R /opt/opendaylight" \
#                                               -a overcloud-full.qcow2
#EOI
#  fi



  # check if ceph should be enabled
  if [ "${deploy_options_array['ceph']}" == 'True' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml"
  fi

  if [ "${deploy_options_array['sdn_controller']}" == 'ovn' ]; then
    # The epoch in deloran's ovs is 1: and in leif's is 0:
    # so we have to execute a downgrade instead of an update
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize \
        --run-command "cd /root/ovs27 && yum update -y *openvswitch*" \
        --run-command "cd /root/ovs27 && yum downgrade -y *openvswitch*" \
        -a overcloud-full.qcow2
EOI
  fi

  # check if HA is enabled
  if [[ "$ha_enabled" == "True" ]]; then
    if [ "$num_control_nodes" -lt 3 ]; then
      echo -e "${red}ERROR: Number of control nodes in inventory is less than 3 and HA is enabled: ${num_control_nodes}. Check your inventory file.${reset}"
      exit 1
    else
     DEPLOY_OPTIONS+=" --control-scale ${num_control_nodes}"
     DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml"
     echo -e "${blue}INFO: Number of control nodes set for deployment: ${num_control_nodes}${reset}"
    fi
  else
    if [ "$num_control_nodes" -lt 1 ]; then
      echo -e "${red}ERROR: Number of control nodes in inventory is less than 1: ${num_control_nodes}. Check your inventory file.${reset}"
      exit 1
    fi
  fi

  if [ "$num_compute_nodes" -le 0 ]; then
    echo -e "${red}ERROR: Invalid number of compute nodes: ${num_compute_nodes}. Check your inventory file.${reset}"
    exit 1
  else
    echo -e "${blue}INFO: Number of compute nodes set for deployment: ${num_compute_nodes}${reset}"
    DEPLOY_OPTIONS+=" --compute-scale ${num_compute_nodes}"
  fi

  DEPLOY_OPTIONS+=" --ntp-server $ntp_server"

  DEPLOY_OPTIONS+=" --control-flavor control --compute-flavor compute"
  if [[ "$virtual" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" -e virtual-environment.yaml"
     echo 'Ensuring Virtual BMC device status'
     for i in $(vbmc list | grep down | awk '{ print $2}'); do
         vbmc start $i
         sleep 5
     done
     vbmc list
  else
    DEPLOY_OPTIONS+=" -e baremetal-environment.yaml"
  fi

  echo -e "${blue}INFO: Deploy options set:\n${DEPLOY_OPTIONS}${reset}"

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
  elif [ "${deploy_options_array['sfc']}" == 'True' ]; then
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI || (echo "SFC config failed, exiting..."; exit 1)
source stackrc
set -o errexit
for node in \$(nova list | grep controller | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"); do
echo "Configuring networking_sfc.conf on \$node"
ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
set -o errexit
sudo ln -s /etc/neutron/networking_sfc.conf /etc/neutron/conf.d/neutron-server/networking_sfc.conf
sudo systemctl restart neutron-server
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
