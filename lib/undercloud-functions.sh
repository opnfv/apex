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
  if ! virsh list --all | grep undercloud > /dev/null; then
      undercloud_nets="default admin_network"
      if [[ $enabled_network_list =~ "public_network" ]]; then
        undercloud_nets+=" public_network"
      fi
      define_vm undercloud hd 30 "$undercloud_nets" 4 12288

      ### this doesn't work for some reason I was getting hangup events so using cp instead
      #virsh vol-upload --pool default --vol undercloud.qcow2 --file $CONFIG/stack/undercloud.qcow2
      #2015-12-05 12:57:20.569+0000: 8755: info : libvirt version: 1.2.8, package: 16.el7_1.5 (CentOS BuildSystem <http://bugs.centos.org>, 2015-11-03-13:56:46, worker1.bsys.centos.org)
      #2015-12-05 12:57:20.569+0000: 8755: warning : virKeepAliveTimerInternal:143 : No response from client 0x7ff1e231e630 after 6 keepalive messages in 35 seconds
      #2015-12-05 12:57:20.569+0000: 8756: warning : virKeepAliveTimerInternal:143 : No response from client 0x7ff1e231e630 after 6 keepalive messages in 35 seconds
      #error: cannot close volume undercloud.qcow2
      #error: internal error: received hangup / error event on socket
      #error: Reconnected to the hypervisor

      local undercloud_dst=/var/lib/libvirt/images/undercloud.qcow2
      cp -f $RESOURCES/undercloud.qcow2 $undercloud_dst

      # resize Undercloud machine
      echo "Checking if Undercloud needs to be resized..."
      undercloud_size=$(LIBGUESTFS_BACKEND=direct virt-filesystems --long -h --all -a $undercloud_dst |grep device | grep -Eo "[0-9\.]+G" | sed -n 's/\([0-9][0-9]*\).*/\1/p')
      if [ "$undercloud_size" -lt 30 ]; then
        qemu-img resize /var/lib/libvirt/images/undercloud.qcow2 +25G
        LIBGUESTFS_BACKEND=direct virt-resize --expand /dev/sda1 $RESOURCES/undercloud.qcow2 $undercloud_dst
        LIBGUESTFS_BACKEND=direct virt-customize -a $undercloud_dst --run-command 'xfs_growfs -d /dev/sda1 || true'
        new_size=$(LIBGUESTFS_BACKEND=direct virt-filesystems --long -h --all -a $undercloud_dst |grep filesystem | grep -Eo "[0-9\.]+G" | sed -n 's/\([0-9][0-9]*\).*/\1/p')
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
    echo "Injecting ssh key to Undercloud VM"
    LIBGUESTFS_BACKEND=direct virt-customize -a $undercloud_dst --run-command "mkdir -p /root/.ssh/" \
        --upload ~/.ssh/id_rsa.pub:/root/.ssh/authorized_keys \
        --run-command "chmod 600 /root/.ssh/authorized_keys && restorecon /root/.ssh/authorized_keys" \
        --run-command "cp /root/.ssh/authorized_keys /home/stack/.ssh/" \
        --run-command "chown stack:stack /home/stack/.ssh/authorized_keys && chmod 600 /home/stack/.ssh/authorized_keys"
    virsh start undercloud
  fi

  sleep 10 # let undercloud get started up

  # get the undercloud VM IP
  CNT=10
  echo -n "${blue}Waiting for Undercloud's dhcp address${reset}"
  undercloud_mac=$(virsh domiflist undercloud | grep default | awk '{ print $5 }')
  while ! $(arp -e | grep ${undercloud_mac} > /dev/null) && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 10
      CNT=$((CNT-1))
  done
  UNDERCLOUD=$(arp -e | grep ${undercloud_mac} | awk {'print $1'})

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

  # ssh key fix for stack user
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "restorecon -r /home/stack"
}

##Copy over the glance images and instackenv json file
##params: none
function configure_undercloud {
  local controller_nic_template compute_nic_template
  echo
  echo "Copying configuration files to Undercloud"
  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
    echo -e "${blue}Network Environment set for Deployment: ${reset}"
    cat /tmp/network-environment.yaml
    scp ${SSH_OPTIONS[@]} /tmp/network-environment.yaml "stack@$UNDERCLOUD":

    # check for ODL L3/ONOS
    if [ "${deploy_options_array['sdn_l3']}" == 'True' ]; then
      ext_net_type=br-ex
    fi

    if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
      ovs_dpdk_bridge='br-phy'
    else
      ovs_dpdk_bridge=''
    fi

    if ! controller_nic_template=$(python3.4 -B $LIB/python/apex_python_utils.py nic-template -r controller -s $NETSETS -i $net_isolation_enabled -t $CONFIG/nics-template.yaml.jinja2 -n "$enabled_network_list" -e "br-ex" -af $ip_addr_family); then
      echo -e "${red}ERROR: Failed to generate controller NIC heat template ${reset}"
      exit 1
    fi

    if ! compute_nic_template=$(python3.4 -B $LIB/python/apex_python_utils.py nic-template -r compute -s $NETSETS -i $net_isolation_enabled -t $CONFIG/nics-template.yaml.jinja2 -n "$enabled_network_list" -e $ext_net_type -af $ip_addr_family -d "$ovs_dpdk_bridge"); then
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
  fi

  # ensure stack user on Undercloud machine has an ssh key
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "if [ ! -e ~/.ssh/id_rsa.pub ]; then ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa; fi"

  if [ "$virtual" == "TRUE" ]; then

      # copy the Undercloud VM's stack user's pub key to
      # root's auth keys so that Undercloud can control
      # vm power on the hypervisor
      ssh ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "cat /home/stack/.ssh/id_rsa.pub" >> /root/.ssh/authorized_keys

      INSTACKENV=$CONFIG/instackenv-virt.json

      # upload instackenv file to Undercloud for virtual deployment
      scp ${SSH_OPTIONS[@]} $INSTACKENV "stack@$UNDERCLOUD":instackenv.json
  fi

  # allow stack to control power management on the hypervisor via sshkey
  # only if this is a virtual deployment
  if [ "$virtual" == "TRUE" ]; then
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
while read -r line; do
  stack_key=\${stack_key}\\\\\\\\n\${line}
done < <(cat ~/.ssh/id_rsa)
stack_key=\$(echo \$stack_key | sed 's/\\\\\\\\n//')
sed -i 's~INSERT_STACK_USER_PRIV_KEY~'"\$stack_key"'~' instackenv.json
EOI
  fi

  # copy stack's ssh key to this users authorized keys
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "cat /home/stack/.ssh/id_rsa.pub" >> ~/.ssh/authorized_keys

  # disable requiretty for sudo
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "sed -i 's/Defaults\s*requiretty//'" /etc/sudoers

  # configure undercloud on Undercloud VM
  echo "Running undercloud configuration."
  echo "Logging undercloud configuration to undercloud:/home/stack/apex-undercloud-install.log"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
if [[ "$net_isolation_enabled" == "TRUE" ]]; then
  sed -i 's/#local_ip/local_ip/' undercloud.conf
  sed -i 's/#network_gateway/network_gateway/' undercloud.conf
  sed -i 's/#network_cidr/network_cidr/' undercloud.conf
  sed -i 's/#dhcp_start/dhcp_start/' undercloud.conf
  sed -i 's/#dhcp_end/dhcp_end/' undercloud.conf
  sed -i 's/#inspection_iprange/inspection_iprange/' undercloud.conf
  sed -i 's/#undercloud_debug/undercloud_debug/' undercloud.conf

  openstack-config --set undercloud.conf DEFAULT local_ip ${admin_network_provisioner_ip}/${admin_network_cidr##*/}
  openstack-config --set undercloud.conf DEFAULT network_gateway ${admin_network_provisioner_ip}
  openstack-config --set undercloud.conf DEFAULT network_cidr ${admin_network_cidr}
  openstack-config --set undercloud.conf DEFAULT dhcp_start ${admin_network_dhcp_range%%,*}
  openstack-config --set undercloud.conf DEFAULT dhcp_end ${admin_network_dhcp_range##*,}
  openstack-config --set undercloud.conf DEFAULT inspection_iprange ${admin_network_introspection_range}
  openstack-config --set undercloud.conf DEFAULT undercloud_debug false
  openstack-config --set undercloud.conf DEFAULT undercloud_hostname "undercloud.${domain_name}"

fi

sudo sed -i '/CephClusterFSID:/c\\  CephClusterFSID: \\x27$(cat /proc/sys/kernel/random/uuid)\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml
sudo sed -i '/CephMonKey:/c\\  CephMonKey: \\x27'"\$(ceph-authtool --gen-print-key)"'\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml
sudo sed -i '/CephAdminKey:/c\\  CephAdminKey: \\x27'"\$(ceph-authtool --gen-print-key)"'\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml

# we assume that packages will not need to be updated with undercloud install
# and that it will be used only to configure the undercloud
# packages updates would need to be handled manually with yum update
sudo cp -f /usr/share/diskimage-builder/elements/yum/bin/install-packages /usr/share/diskimage-builder/elements/yum/bin/install-packages.bak
cat << 'EOF' | sudo tee /usr/share/diskimage-builder/elements/yum/bin/install-packages > /dev/null
#!/bin/sh
exit 0
EOF

openstack undercloud install &> apex-undercloud-install.log || {
    # cat the undercloud install log incase it fails
    echo "ERROR: openstack undercloud install has failed. Dumping Log:"
    cat apex-undercloud-install.log
    exit 1
}

sleep 30
sudo systemctl restart openstack-glance-api
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

sudo sed -i '/num_engine_workers/c\num_engine_workers = 2' /etc/heat/heat.conf
sudo sed -i '/#workers\s=/c\workers = 2' /etc/heat/heat.conf
sudo systemctl restart openstack-heat-engine
sudo systemctl restart openstack-heat-api
EOI

# configure external network
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" << EOI
if [[ "$public_network_vlan" != "native" ]]; then
  cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-vlan${public_network_vlan}
DEVICE=vlan${public_network_vlan}
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSIntPort
BOOTPROTO=static
IPADDR=${public_network_provisioner_ip}
PREFIX=${public_network_cidr##*/}
OVS_BRIDGE=br-ctlplane
OVS_OPTIONS="tag=${public_network_vlan}"
EOF
  ifup vlan${public_network_vlan}
else
  if ! ip a s eth2 | grep ${public_network_provisioner_ip} > /dev/null; then
      ip a a ${public_network_provisioner_ip}/${public_network_cidr##*/} dev eth2
      ip link set up dev eth2
  fi
fi
EOI

# WORKAROUND: must restart the above services to fix sync problem with nova compute manager
# TODO: revisit and file a bug if necessary. This should eventually be removed
# as well as glance api problem
echo -e "${blue}INFO: Sleeping 15 seconds while services come back from restart${reset}"
sleep 15

}
