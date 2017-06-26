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
  if [ "${deploy_options_array['dataplane']}" == 'fdio' ]; then
    ext_net_type=vpp_interface
  else
    ext_net_type=br-ex
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
set -e
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

if [ "\$(uname -i)" == 'aarch64' ]; then

# These two fixes are done in the base OOO image build right now
# keeping them here to know that they are done and in case we need
# to take care of them in the future.
#    # remove syslinux references for aarch64
#    sudo sh -xc 'cd /etc/puppet/modules/ironic/manifests && patch -p0 < puppet-ironic-manifests-pxe-pp-aarch64.patch'
#    sudo sed -i '/syslinux-extlinux/d' /usr/share/instack-undercloud/puppet-stack-config/puppet-stack-config.pp
#
#    # disable use_linkat in swift
#    sudo sed -i 's/o_tmpfile_supported()/False/' /usr/lib/python2.7/site-packages/swift/obj/diskfile.py

    openstack-config --set undercloud.conf DEFAULT ipxe_enabled false
    sudo sed -i '/    _link_ip_address_pxe_configs/a\\        _link_mac_pxe_configs(task)' /usr/lib/python2.7/site-packages/ironic/common/pxe_utils.py
fi

openstack undercloud install &> apex-undercloud-install.log || {
    # cat the undercloud install log incase it fails
    echo "ERROR: openstack undercloud install has failed. Dumping Log:"
    cat apex-undercloud-install.log
    exit 1
}

if [ "\$(uname -i)" == 'aarch64' ]; then
sudo yum -y reinstall grub2-efi shim
sudo cp /boot/efi/EFI/centos/grubaa64.efi /tftpboot/grubaa64.efi
sudo mkdir -p /tftpboot/EFI/centos
sudo tee /tftpboot/EFI/centos/grub.cfg > /dev/null << EOF
set default=master
set timeout=5
set hidden_timeout_quiet=false

menuentry "master"  {
configfile /tftpboot/\\\$net_default_ip.conf
}
EOF
sudo chmod 644 /tftpboot/EFI/centos/grub.cfg
sudo openstack-config --set /etc/ironic/ironic.conf pxe uefi_pxe_config_template \\\$pybasedir/drivers/modules/pxe_grub_config.template
sudo openstack-config --set /etc/ironic/ironic.conf pxe uefi_pxe_bootfile_name grubaa64.efi
sudo service openstack-ironic-conductor restart
sudo sed -i 's/linuxefi/linux/g' /usr/lib/python2.7/site-packages/ironic/drivers/modules/pxe_grub_config.template
sudo sed -i 's/initrdefi/initrd/g' /usr/lib/python2.7/site-packages/ironic/drivers/modules/pxe_grub_config.template
echo '' | sudo tee --append /tftpboot/map-file > /dev/null
echo 'r ^/EFI/centos/grub.cfg-(.*) /tftpboot/pxelinux.cfg/\\1' | sudo tee --append /tftpboot/map-file > /dev/null
sudo service xinetd restart
fi

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
