#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

##verify vm exists, an has a dhcp lease assigned to it
##params: none
function setup_undercloud_vm {
  local libvirt_imgs=/var/lib/libvirt/images
  if ! virsh list --all | grep undercloud > /dev/null; then
      undercloud_nets="default admin"
      if [[ $enabled_network_list =~ "external" ]]; then
        undercloud_nets+=" external"
      fi
      define_vm undercloud hd 30 "$undercloud_nets" 4 12288

      ### this doesn't work for some reason I was getting hangup events so using cp instead
      #virsh vol-upload --pool default --vol undercloud.qcow2 --file $BASE/stack/undercloud.qcow2
      #2015-12-05 12:57:20.569+0000: 8755: info : libvirt version: 1.2.8, package: 16.el7_1.5 (CentOS BuildSystem <http://bugs.centos.org>, 2015-11-03-13:56:46, worker1.bsys.centos.org)
      #2015-12-05 12:57:20.569+0000: 8755: warning : virKeepAliveTimerInternal:143 : No response from client 0x7ff1e231e630 after 6 keepalive messages in 35 seconds
      #2015-12-05 12:57:20.569+0000: 8756: warning : virKeepAliveTimerInternal:143 : No response from client 0x7ff1e231e630 after 6 keepalive messages in 35 seconds
      #error: cannot close volume undercloud.qcow2
      #error: internal error: received hangup / error event on socket
      #error: Reconnected to the hypervisor

      cp -f $IMAGES/undercloud.qcow2 $libvirt_imgs/undercloud.qcow2
      cp -f $IMAGES/overcloud-full.vmlinuz $libvirt_imgs/overcloud-full.vmlinuz
      cp -f $IMAGES/overcloud-full.initrd $libvirt_imgs/overcloud-full.initrd

      # resize Undercloud machine
      echo "Checking if Undercloud needs to be resized..."
      undercloud_size=$(LIBGUESTFS_BACKEND=direct virt-filesystems --long -h --all -a $libvirt_imgs/undercloud.qcow2 |grep device | grep -Eo "[0-9\.]+G" | sed -n 's/\([0-9][0-9]*\).*/\1/p')
      if [ "$undercloud_size" -lt 30 ]; then
        qemu-img resize /var/lib/libvirt/images/undercloud.qcow2 +25G
        LIBGUESTFS_BACKEND=direct virt-resize --expand /dev/sda1 $IMAGES/undercloud.qcow2 $libvirt_imgs/undercloud.qcow2
        LIBGUESTFS_BACKEND=direct virt-customize -a $libvirt_imgs/undercloud.qcow2 --run-command 'xfs_growfs -d /dev/sda1 || true'
        new_size=$(LIBGUESTFS_BACKEND=direct virt-filesystems --long -h --all -a $libvirt_imgs/undercloud.qcow2 |grep filesystem | grep -Eo "[0-9\.]+G" | sed -n 's/\([0-9][0-9]*\).*/\1/p')
        if [ "$new_size" -lt 30 ]; then
          echo "Error resizing Undercloud machine, disk size is ${new_size}"
          exit 1
        else
          echo "Undercloud successfully resized"
        fi
      else
        echo "Skipped Undercloud resize, upstream is large enough"
      fi

  else
      echo "Found existing Undercloud VM, exiting."
      exit 1
  fi

  # if the VM is not running update the authkeys and start it
  if ! virsh list | grep undercloud > /dev/null; then
    if [ "$debug" == 'TRUE' ]; then
      LIBGUESTFS_BACKEND=direct virt-customize -a $libvirt_imgs/undercloud.qcow2 --root-password password:opnfvapex
    fi

    echo "Injecting ssh key to Undercloud VM"
    LIBGUESTFS_BACKEND=direct virt-customize -a $libvirt_imgs/undercloud.qcow2 --run-command "mkdir -p /root/.ssh/" \
        --upload ~/.ssh/id_rsa.pub:/root/.ssh/authorized_keys \
        --run-command "chmod 600 /root/.ssh/authorized_keys && restorecon /root/.ssh/authorized_keys" \
        --run-command "cp /root/.ssh/authorized_keys /home/stack/.ssh/" \
        --run-command "chown stack:stack /home/stack/.ssh/authorized_keys && chmod 600 /home/stack/.ssh/authorized_keys"
    virsh start undercloud
    virsh autostart undercloud
  fi

  sleep 10 # let undercloud get started up

  # get the undercloud VM IP
  CNT=10
  echo -n "${blue}Waiting for Undercloud's dhcp address${reset}"
  undercloud_mac=$(virsh domiflist undercloud | grep default | awk '{ print $5 }')
  while ! $(arp -en | grep ${undercloud_mac} > /dev/null) && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 10
      CNT=$((CNT-1))
  done
  UNDERCLOUD=$(arp -en | grep ${undercloud_mac} | awk {'print $1'})

  if [ -z "$UNDERCLOUD" ]; then
    echo "\n\nCan't get IP for Undercloud. Can Not Continue."
    exit 1
  else
     echo -e "${blue}\rUndercloud VM has IP $UNDERCLOUD${reset}"
  fi

  CNT=10
  echo -en "${blue}\rValidating Undercloud VM connectivity${reset}"
  while ! ping -c 1 $UNDERCLOUD > /dev/null && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 3
      CNT=$((CNT-1))
  done
  if [ "$CNT" -eq 0 ]; then
      echo "Failed to contact Undercloud. Can Not Continue"
      exit 1
  fi
  CNT=10
  while ! ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "echo ''" 2>&1> /dev/null && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 3
      CNT=$((CNT-1))
  done
  if [ "$CNT" -eq 0 ]; then
      echo "Failed to connect to Undercloud. Can Not Continue"
      exit 1
  fi

  # extra space to overwrite the previous connectivity output
  echo -e "${blue}\r                                                                 ${reset}"
  sleep 1

  # ensure stack user on Undercloud machine has an ssh key
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "if [ ! -e ~/.ssh/id_rsa.pub ]; then ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa; fi"

  # ssh key fix for stack user
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "restorecon -r /home/stack"
}

##Copy over the glance images and instackenv json file
##params: none
function configure_undercloud {
  local controller_nic_template compute_nic_template
  echo
  echo "Copying configuration files to Undercloud"
  echo -e "${blue}Network Environment set for Deployment: ${reset}"
  cat $APEX_TMP_DIR/network-environment.yaml
  scp ${SSH_OPTIONS[@]} $APEX_TMP_DIR/network-environment.yaml "stack@$UNDERCLOUD":

  # check for ODL L3/ONOS
  if [ "${deploy_options_array['sdn_l3']}" == 'True' ]; then
    if [ "${deploy_options_array['dataplane']}" == 'fdio' ]; then
      ext_net_type=vpp_interface
    else
      ext_net_type=br-ex
    fi
  fi

  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    ovs_dpdk_bridge='br-phy'
  else
    ovs_dpdk_bridge=''
  fi

  if ! controller_nic_template=$(python3 -B $LIB/python/apex_python_utils.py nic-template -r controller -s $NETSETS -t $BASE/nics-template.yaml.jinja2 -e "br-ex" --deploy-settings-file $DEPLOY_SETTINGS_FILE); then
    echo -e "${red}ERROR: Failed to generate controller NIC heat template ${reset}"
    exit 1
  fi

  if ! compute_nic_template=$(python3 -B $LIB/python/apex_python_utils.py nic-template -r compute -s $NETSETS -t $BASE/nics-template.yaml.jinja2 -e $ext_net_type -d "$ovs_dpdk_bridge" --deploy-settings-file $DEPLOY_SETTINGS_FILE); then
    echo -e "${red}ERROR: Failed to generate compute NIC heat template ${reset}"
    exit 1
  fi
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
mkdir nics/
cat > nics/controller.yaml << EOF
$controller_nic_template
EOF
cat > nics/compute.yaml << EOF
$compute_nic_template
EOF
EOI

  # disable requiretty for sudo
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "sed -i 's/Defaults\s*requiretty//'" /etc/sudoers

  # configure undercloud on Undercloud VM
  echo "Running undercloud installation and configuration."
  echo "Logging undercloud installation to stack@undercloud:/home/stack/apex-undercloud-install.log"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
openstack-config --set undercloud.conf DEFAULT local_ip ${admin_installer_vm_ip}/${admin_cidr##*/}
openstack-config --set undercloud.conf DEFAULT network_gateway ${admin_installer_vm_ip}
openstack-config --set undercloud.conf DEFAULT network_cidr ${admin_cidr}
openstack-config --set undercloud.conf DEFAULT dhcp_start ${admin_dhcp_range%%,*}
openstack-config --set undercloud.conf DEFAULT dhcp_end ${admin_dhcp_range##*,}
openstack-config --set undercloud.conf DEFAULT inspection_iprange ${admin_introspection_range}
openstack-config --set undercloud.conf DEFAULT undercloud_debug false
openstack-config --set undercloud.conf DEFAULT undercloud_hostname "undercloud.${domain_name}"
openstack-config --set undercloud.conf DEFAULT enable_ui false
openstack-config --set undercloud.conf DEFAULT undercloud_update_packages false
sudo openstack-config --set /etc/ironic/ironic.conf disk_utils iscsi_verify_attempts 30
sudo openstack-config --set /etc/ironic/ironic.conf disk_partitioner check_device_max_retries 40

if [[ -n "${deploy_options_array['ceph_device']}" ]]; then
    sed -i '/ExtraConfig/a\\    ceph::profile::params::osds: {\\x27${deploy_options_array['ceph_device']}\\x27: {}}' ${ENV_FILE}
fi

sudo sed -i '/CephClusterFSID:/c\\  CephClusterFSID: \\x27$(cat /proc/sys/kernel/random/uuid)\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml
sudo sed -i '/CephMonKey:/c\\  CephMonKey: \\x27'"\$(ceph-authtool --gen-print-key)"'\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml
sudo sed -i '/CephAdminKey:/c\\  CephAdminKey: \\x27'"\$(ceph-authtool --gen-print-key)"'\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml

#####
# TEMP WORKAROUND, REMOVE WHEN SNAPS SUPPORTS GLANCE API v2
# JIRA: SNAPS-66
#####
sudo sed -i '/glance::api::enable_v1_api/ s/false/true/' -i /usr/share/openstack-tripleo-heat-templates/puppet/services/glance-api.yaml


openstack undercloud install &> apex-undercloud-install.log || {
    # cat the undercloud install log incase it fails
    echo "ERROR: openstack undercloud install has failed. Dumping Log:"
    cat apex-undercloud-install.log
    exit 1
}

# Set nova domain name
sudo openstack-config --set /etc/nova/nova.conf DEFAULT dns_domain ${domain_name}
sudo openstack-config --set /etc/nova/nova.conf DEFAULT dhcp_domain ${domain_name}
sudo systemctl restart openstack-nova-conductor
sudo systemctl restart openstack-nova-compute
sudo systemctl restart openstack-nova-api
sudo systemctl restart openstack-nova-scheduler

# Set neutron domain name
sudo openstack-config --set /etc/neutron/neutron.conf DEFAULT dns_domain ${domain_name}
sudo systemctl restart neutron-server
sudo systemctl restart neutron-dhcp-agent
EOI

# configure external network
if [[ "$enabled_network_list" =~ "external" ]]; then
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" << EOI
if [[ "$external_installer_vm_vlan" != "native" ]]; then
  cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-vlan${external_installer_vm_vlan}
DEVICE=vlan${external_installer_vm_vlan}
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSIntPort
BOOTPROTO=static
IPADDR=${external_installer_vm_ip}
PREFIX=${external_cidr##*/}
OVS_BRIDGE=br-ctlplane
OVS_OPTIONS="tag=${external_installer_vm_vlan}"
EOF
  ifup vlan${external_installer_vm_vlan}
else
  if ! ip a s eth2 | grep ${external_installer_vm_ip} > /dev/null; then
      ip a a ${external_installer_vm_ip}/${external_cidr##*/} dev eth2
      ip link set up dev eth2
  fi
fi
EOI
fi

}
