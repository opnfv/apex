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
  if [[ "${#deploy_options_array[@]}" -eq 0 || "${deploy_options_array['sdn_controller']}" == 'opendaylight' ]]; then
    if [ "${deploy_options_array['sdn_l3']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_l3.yaml"
    elif [ "${deploy_options_array['sfc']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_sfc.yaml"
    elif [ "${deploy_options_array['vpn']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_sdnvpn.yaml"
    elif [ "${deploy_options_array['vpp']}" == 'True' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_fdio.yaml"
    else
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight.yaml"
    fi
    SDN_IMAGE=opendaylight
    if [ "${deploy_options_array['sfc']}" == 'True' ]; then
      SDN_IMAGE+=-sfc
      if [ ! -f $RESOURCES/overcloud-full-${SDN_IMAGE}.qcow2 ]; then
          echo "${red} $RESOURCES/overcloud-full-${SDN_IMAGE}.qcow2 is required to execute an SFC deployment."
          echo "Please install the opnfv-apex-opendaylight-sfc package to provide this overcloud image for deployment.${reset}"
          exit 1
      fi
    fi
  elif [ "${deploy_options_array['sdn_controller']}" == 'opendaylight-external' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight-external.yaml"
    SDN_IMAGE=opendaylight
  elif [ "${deploy_options_array['sdn_controller']}" == 'onos' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/onos.yaml"
    SDN_IMAGE=onos
  elif [ "${deploy_options_array['sdn_controller']}" == 'opencontrail' ]; then
    echo -e "${red}ERROR: OpenContrail is currently unsupported...exiting${reset}"
    exit 1
  elif [[ -z "${deploy_options_array['sdn_controller']}" || "${deploy_options_array['sdn_controller']}" == 'False' ]]; then
    echo -e "${blue}INFO: SDN Controller disabled...will deploy nosdn scenario${reset}"
    SDN_IMAGE=opendaylight
  else
    echo "${red}Invalid sdn_controller: ${deploy_options_array['sdn_controller']}${reset}"
    echo "${red}Valid choices are opendaylight, opendaylight-external, onos, opencontrail, False, or null${reset}"
    exit 1
  fi



  # Make sure the correct overcloud image is available
  if [ ! -f $RESOURCES/overcloud-full-${SDN_IMAGE}.qcow2 ]; then
      echo "${red} $RESOURCES/overcloud-full-${SDN_IMAGE}.qcow2 is required to execute your deployment."
      echo "Both ONOS and OpenDaylight are currently deployed from this image."
      echo "Please install the opnfv-apex package to provide this overcloud image for deployment.${reset}"
      exit 1
  fi

  echo "Copying overcloud image to Undercloud"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "rm -f overcloud-full.qcow2"
  scp ${SSH_OPTIONS[@]} $RESOURCES/overcloud-full-${SDN_IMAGE}.qcow2 "stack@$UNDERCLOUD":overcloud-full.qcow2

  # Install ovs-dpdk inside the overcloud image if it is enabled.
  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
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
                                               --run-command "yum install -y /root/dpdk_rpms/*" \
                                               -a overcloud-full.qcow2
EOI
  elif [ "${deploy_options_array['dataplane']}" != 'ovs' ]; then
    echo "${red}${deploy_options_array['dataplane']} not supported${reset}"
    exit 1
  fi

  # Set ODL version accordingly
  if [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' && "${deploy_options_array['odl_version']}" == 'boron' ]]; then
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
      LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum -y remove opendaylight" \
                                               --run-command "yum -y install /root/boron/*" \
                                               -a overcloud-full.qcow2
EOI
  fi

  ### VSPERF ###
  if [[ "${deploy_options_array['vsperf']}" == 'True' ]]; then
      if [ "$internet" == "false" ]; then
          echo "${red}\nVSPERF enabled but internet connectivity not present"
          echo "Internet connectivity not present\n\n${reset}"
      fi
      echo "${blue}\nVSPERF enabled, adding it to overcloud image\n${reset}"
      # if vsperf is enabled, clone the git repo and add a service script to kick of the installation
      ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" << EOI
cat > /tmp/vsperf-install.service << EOF
[Unit]
Description=VSPERF install script
After=network.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "if [[ \$(hostname) =~ "overcloud-novacompute-0" ]]; then cd /var/opt/vsperf/systems/ && ./build_base_machine.sh 2>&1 > /var/log/vsperf.log; fi"
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
LIBGUESTFS_BACKEND=direct virt-customize \
        --upload /tmp/vsperf-install.service:/etc/systemd/system/vsperf-install.service \
        -a /home/stack/overcloud-full.qcow2
EOI
  fi

  # Add performance deploy options if they have been set
  if [ ! -z "${deploy_options_array['performance']}" ]; then

    # Remove previous kernel args files per role
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "rm -f Compute-kernel_params.txt"
    ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "rm -f Controller-kernel_params.txt"

    # Push performance options to subscript to modify per-role images as needed
    for option in "${performance_options[@]}" ; do
      echo -e "${blue}Setting performance option $option${reset}"
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "bash build_perf_image.sh $option"
    done

    # Build IPA kernel option ramdisks
    ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" <<EOI
/bin/cp -f /home/stack/ironic-python-agent.initramfs /root/
mkdir -p ipa/
pushd ipa
gunzip -c ../ironic-python-agent.initramfs | cpio -i
if [ ! -f /home/stack/Compute-kernel_params.txt ]; then
  touch /home/stack/Compute-kernel_params.txt
  chown stack /home/stack/Compute-kernel_params.txt
fi
/bin/cp -f /home/stack/Compute-kernel_params.txt tmp/kernel_params.txt
echo "Compute params set: "
cat tmp/kernel_params.txt
/bin/cp -f /root/image.py usr/lib/python2.7/site-packages/ironic_python_agent/extensions/image.py
/bin/cp -f /root/image.pyc usr/lib/python2.7/site-packages/ironic_python_agent/extensions/image.pyc
find . | cpio -o -H newc | gzip > /home/stack/Compute-ironic-python-agent.initramfs
chown stack /home/stack/Compute-ironic-python-agent.initramfs
if [ ! -f /home/stack/Controller-kernel_params.txt ]; then
  touch /home/stack/Controller-kernel_params.txt
  chown stack /home/stack/Controller-kernel_params.txt
fi
/bin/cp -f /home/stack/Controller-kernel_params.txt tmp/kernel_params.txt
echo "Controller params set: "
cat tmp/kernel_params.txt
find . | cpio -o -H newc | gzip > /home/stack/Controller-ironic-python-agent.initramfs
chown stack /home/stack/Controller-ironic-python-agent.initramfs
popd
/bin/rm -rf ipa/
EOI

    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml"
  fi

  # make sure ceph is installed
  DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml"

  # scale compute nodes according to inventory
  total_nodes=$(ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "cat /home/stack/instackenv.json | grep -c memory")

  # check if HA is enabled
  if [[ "$ha_enabled" == "True" ]]; then
     DEPLOY_OPTIONS+=" --control-scale 3"
     compute_nodes=$((total_nodes - 3))
     DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml"
  else
     compute_nodes=$((total_nodes - 1))
  fi

  if [ "$compute_nodes" -le 0 ]; then
    echo -e "${red}ERROR: Invalid number of compute nodes: ${compute_nodes}. Check your inventory file.${reset}"
    exit 1
  else
    echo -e "${blue}INFO: Number of compute nodes set for deployment: ${compute_nodes}${reset}"
    DEPLOY_OPTIONS+=" --compute-scale ${compute_nodes}"
  fi

  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
     #DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml"
     DEPLOY_OPTIONS+=" -e network-environment.yaml"
  fi

  if [[ "$ha_enabled" == "True" ]] || [[ "$net_isolation_enabled" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --ntp-server $ntp_server"
  fi

  if [[ ! "$virtual" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --control-flavor control --compute-flavor compute"
  else
     DEPLOY_OPTIONS+=" -e virtual-environment.yaml"
  fi

  DEPLOY_OPTIONS+=" -e opnfv-environment.yaml"

  echo -e "${blue}INFO: Deploy options set:\n${DEPLOY_OPTIONS}${reset}"

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
if [ "$debug" == 'TRUE' ]; then
    LIBGUESTFS_BACKEND=direct virt-customize -a overcloud-full.qcow2 --root-password password:opnfvapex
fi

source stackrc
set -o errexit
echo "Uploading overcloud glance images"
openstack overcloud image upload

echo "Configuring undercloud and discovering nodes"
openstack baremetal import --json instackenv.json
openstack baremetal configure boot
bash -x set_perf_images.sh ${performance_roles[@]}
#if [[ -z "$virtual" ]]; then
#  openstack baremetal introspection bulk start
#fi
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
if ! heat stack-list | grep CREATE_COMPLETE 1>/dev/null; then
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
cinder quota-show \$(openstack project list | grep admin | awk {'print \$2'})
EOI
  fi
}
