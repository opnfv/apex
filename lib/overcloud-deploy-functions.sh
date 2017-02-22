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

  # OPNFV Default Environment and Network settings
  DEPLOY_OPTIONS+=" -e ${ENV_FILE}"
  DEPLOY_OPTIONS+=" -e network-environment.yaml"

  # Custom Deploy Environment Templates
  if [[ "${#deploy_options_array[@]}" -eq 0 || "${deploy_options_array['sdn_controller']}" == 'opendaylight' ]]; then
    if [ "${deploy_options_array['sfc']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_sfc.yaml"
    elif [ "${deploy_options_array['vpn']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight-bgpvpn.yaml"
      if [ "${deploy_options_array['gluon']}" == 'True' ]; then
        DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/services/gluon.yaml"
      fi
    elif [ "${deploy_options_array['vpp']}" == 'True' ]; then
      if [ "${deploy_options_array['sdn_l3']}" == "True" ]; then
        DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight-honeycomb.yaml"
      else
        DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight-honeycomb-l2.yaml"
      fi
    else
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-opendaylight-l3.yaml"
    fi
    SDN_IMAGE=opendaylight
  elif [ "${deploy_options_array['sdn_controller']}" == 'opendaylight-external' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight-external.yaml"
    SDN_IMAGE=opendaylight
  elif [ "${deploy_options_array['sdn_controller']}" == 'onos' ]; then
    echo -e "${red}ERROR: ONOS is unsupported in Danube...exiting${reset}"
    exit 1
    #if [ "${deploy_options_array['sfc']}" == 'True' ]; then
    #  DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/onos_sfc.yaml"
    #else
    #  DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/onos.yaml"
    #fi
    #SDN_IMAGE=onos
  elif [ "${deploy_options_array['sdn_controller']}" == 'opencontrail' ]; then
    echo -e "${red}ERROR: OpenContrail is currently unsupported...exiting${reset}"
    exit 1
  elif [[ -z "${deploy_options_array['sdn_controller']}" || "${deploy_options_array['sdn_controller']}" == 'False' ]]; then
    echo -e "${blue}INFO: SDN Controller disabled...will deploy nosdn scenario${reset}"
    if [ "${deploy_options_array['vpp']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/neutron-ml2-networking-vpp.yaml"
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

  # Make sure the correct overcloud image is available
  if [ ! -f $IMAGES/overcloud-full-${SDN_IMAGE}.qcow2 ]; then
      echo "${red} $IMAGES/overcloud-full-${SDN_IMAGE}.qcow2 is required to execute your deployment."
      echo "Please install the opnfv-apex package to provide this overcloud image for deployment.${reset}"
      exit 1
  fi

  echo "Copying overcloud image to Undercloud"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "rm -f overcloud-full.qcow2"
  scp ${SSH_OPTIONS[@]} $IMAGES/overcloud-full-${SDN_IMAGE}.qcow2 "stack@$UNDERCLOUD":overcloud-full.qcow2

  if [ "${deploy_options_array['vpn']}" == 'True' ]; then
      echo -e "${blue}INFO: Enabling ZRPC and Quagga${reset}"
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum -y install /root/quagga/*.rpm" \
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
        LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum install -y /root/dpdk_rpms/*" \
                                                 --run-command "sed -i '/RuntimeDirectoryMode=.*/d' /usr/lib/systemd/system/openvswitch-nonetwork.service" \
                                                 --run-command "printf \"%s\\n\" RuntimeDirectoryMode=0775 Group=qemu UMask=0002 >> /usr/lib/systemd/system/openvswitch-nonetwork.service" \
                                                 --run-command "sed -i 's/\\(^\\s\\+\\)\\(start_daemon "$OVS_VSWITCHD_PRIORITY"\\)/\\1umask 0002 \\&\\& \\2/' /usr/share/openvswitch/scripts/ovs-ctl" \
                                                 -a overcloud-full.qcow2
      fi

EOI

  elif [ "${deploy_options_array['dataplane']}" != 'ovs' ]; then
    echo "${red}${deploy_options_array['dataplane']} not supported${reset}"
    exit 1
  fi

  if [ "$debug" == 'TRUE' ]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "LIBGUESTFS_BACKEND=direct virt-customize -a overcloud-full.qcow2 --root-password password:opnfvapex"
  fi

  # upgrade ovs into ovs 2.5.90 with NSH function if SFC is enabled
  if [[ "${deploy_options_array['sfc']}" == 'True' && "${deploy_options_array['dataplane']}" == 'ovs' ]]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
         LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum install -y /root/ovs/rpm/rpmbuild/RPMS/x86_64/${ovs_kmod_rpm_name}" \
                                                  --run-command "yum upgrade -y /root/ovs/rpm/rpmbuild/RPMS/x86_64/${ovs_rpm_name}" \
                                                  -a overcloud-full.qcow2
EOI
  fi

  #Configure routing node for odl_l3-fdio
  if [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' && "${deploy_options_array['dataplane']}" == 'fdio' && "${deploy_options_array['sdn_l3']}" == 'True' ]]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
       sed -i "/opendaylight::vpp_routing_node:/c\    opendaylight::vpp_routing_node: ${deploy_options_array['odl_routing_node']}.${domain_name}" ${ENV_FILE}
EOI
  fi

  if [ -n "${deploy_options_array['performance']}" ]; then
    for option in "${performance_options[@]}" ; do
    arr=($option)
    # use compute's kernel settings for all nodes for now.
    if [ "${arr[0]}" == "Compute" ] && [ "${arr[1]}" == "kernel" ]; then
      kernel_args+=" ${arr[2]}=${arr[3]}"
    fi
    done

    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
       sed -i "/ComputeKernelArgs:/c\  ComputeKernelArgs: '$kernel_args'" ${ENV_FILE}
       sed -i "$ a\resource_registry:\n  OS::TripleO::NodeUserData: first-boot.yaml" ${ENV_FILE}
       sed -i "/NovaSchedulerDefaultFilters:/c\  NovaSchedulerDefaultFilters: 'RamFilter,ComputeFilter,AvailabilityZoneFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,NUMATopologyFilter'" ${ENV_FILE}
EOI
  fi

  # Set ODL version accordingly
  if [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' && -n "${deploy_options_array['odl_version']}" ]]; then
    case "${deploy_options_array['odl_version']}" in
      beryllium) odl_version=''
              ;;
      boron)  odl_version='boron'
              ;;
      carbon) odl_version='master'
              ;;
      *) echo -e "${red}Invalid ODL version ${deploy_options_array['odl_version']}.  Please use 'carbon' or 'boron' values.${reset}"
         exit 1
         ;;
    esac

    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum -y remove opendaylight" \
                                               --run-command "yum -y install /root/${odl_version}/*" \
                                               -a overcloud-full.qcow2
EOI
  fi


  # check if ceph should be enabled
  if [ "${deploy_options_array['ceph']}" == 'True' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml"
  fi

  # get number of nodes available in inventory
  num_control_nodes=$(ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "grep -c profile:control /home/stack/instackenv.json")
  num_compute_nodes=$(ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "grep -c profile:compute /home/stack/instackenv.json")

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
openstack baremetal import --json instackenv.json

if [[ -z "$virtual" ]]; then
  openstack baremetal introspection bulk start
  if [[ -n "$root_disk_list" ]]; then
    openstack baremetal configure boot --root-device=${root_disk_list}
  else
    openstack baremetal configure boot
  fi
else
  openstack baremetal configure boot
fi

echo "Configuring flavors"
for flavor in baremetal control compute; do
  echo -e "${blue}INFO: Updating flavor: \${flavor}${reset}"
  if openstack flavor list | grep \${flavor}; then
    openstack flavor delete \${flavor}
  fi
  openstack flavor create --id auto --ram 4096 --disk 39 --vcpus 1 \${flavor}
  if ! openstack flavor list | grep \${flavor}; then
    echo -e "${red}ERROR: Unable to create flavor \${flavor}${reset}"
  fi
done
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" baremetal
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="control" control
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="compute" compute
echo "Configuring nameserver on ctlplane network"
dns_server_ext=''
for dns_server in ${dns_servers}; do
  dns_server_ext="\${dns_server_ext} --dns-nameserver \${dns_server}"
done
neutron subnet-update \$(neutron subnet-list | grep -Ev "id|tenant|external|storage" | grep -v \\\\-\\\\- | awk {'print \$2'}) \${dns_server_ext}
sed -i '/CloudDomain:/c\  CloudDomain: '${domain_name} ${ENV_FILE}
echo "Executing overcloud deployment, this should run for an extended period without output."
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

  # Configure DPDK
  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI || (echo "DPDK config failed, exiting..."; exit 1)
source stackrc
set -o errexit
for node in \$(nova list | grep novacompute | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"); do
echo "Running DPDK test app on \$node"
ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
set -o errexit
sudo dpdk_helloworld --no-pci
sudo dpdk_nic_bind -s
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
