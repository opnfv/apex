#!/bin/bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Deploy script to install provisioning server for OPNFV Apex
# author: Dan Radez (dradez@redhat.com)
# author: Tim Rozet (trozet@redhat.com)
#
# Based on RDO Manager http://www.rdoproject.org

set -e

##VARIABLES
reset=$(tput sgr0 || echo "")
blue=$(tput setaf 4 || echo "")
red=$(tput setaf 1 || echo "")
green=$(tput setaf 2 || echo "")

interactive="FALSE"
ping_site="8.8.8.8"
ntp_server="pool.ntp.org"
net_isolation_enabled="TRUE"
post_config="TRUE"
debug="FALSE"

declare -i CNT
declare UNDERCLOUD
declare -A deploy_options_array
declare -a performance_options
declare -A NET_MAP

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
DEPLOY_OPTIONS=""
CONFIG=${CONFIG:-'/var/opt/opnfv'}
RESOURCES=${RESOURCES:-"$CONFIG/images"}
LIB=${LIB:-"$CONFIG/lib"}
OPNFV_NETWORK_TYPES="admin_network private_network public_network storage_network api_network"

VM_CPUS=4
VM_RAM=8
VM_COMPUTES=2

# Netmap used to map networks to OVS bridge names
NET_MAP['admin_network']="br-admin"
NET_MAP['private_network']="br-private"
NET_MAP['public_network']="br-public"
NET_MAP['storage_network']="br-storage"
NET_MAP['api_network']="br-api"
ext_net_type="interface"
ip_address_family=4

# Libraries
lib_files=(
$LIB/common-functions.sh
$LIB/parse-functions.sh
$LIB/utility-functions.sh
$LIB/installer/onos/onos_gw_mac_update.sh
)
for lib_file in ${lib_files[@]}; do
  if ! source $lib_file; then
    echo -e "${red}ERROR: Failed to source $lib_file${reset}"
    exit 1
  fi
done

##FUNCTIONS
##checks if prefix exists in string
##params: string, prefix
##usage: contains_prefix "deploy_setting_launcher=1" "deploy_setting"
contains_prefix() {
  local mystr=$1
  local prefix=$2
  if echo $mystr | grep -E "^$prefix.*$" > /dev/null; then
    return 0
  else
    return 1
  fi
}

##verify internet connectivity
#params: none
function verify_internet {
  if ping -c 2 $ping_site > /dev/null; then
    if ping -c 2 www.google.com > /dev/null; then
      echo "${blue}Internet connectivity detected${reset}"
      return 0
    else
      echo "${red}Internet connectivity detected, but DNS lookup failed${reset}"
      return 1
    fi
  else
    echo "${red}No internet connectivity detected${reset}"
    return 1
  fi
}

##download dependencies if missing and configure host
#params: none
function configure_deps {
  if ! verify_internet; then
    echo "${red}Will not download dependencies${reset}"
    internet=false
  fi

  # verify ip forwarding
  if sysctl net.ipv4.ip_forward | grep 0; then
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo sh -c "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf"
  fi

  # ensure no dhcp server is running on jumphost
  if ! sudo systemctl status dhcpd | grep dead; then
    echo "${red}WARN: DHCP Server detected on jumphost, disabling...${reset}"
    sudo systemctl stop dhcpd
    sudo systemctl disable dhcpd
  fi

  # ensure networks are configured
  systemctl status libvirtd || systemctl start libvirtd
  systemctl status openvswitch || systemctl start openvswitch

  # If flat we only use admin network
  if [[ "$net_isolation_enabled" == "FALSE" ]]; then
    virsh_enabled_networks="admin_network"
    enabled_network_list="admin_network"
  # For baremetal we only need to create/attach Undercloud to admin and public
  elif [ "$virtual" == "FALSE" ]; then
    virsh_enabled_networks="admin_network public_network"
  else
    virsh_enabled_networks=$enabled_network_list
  fi

  # ensure default network is configured correctly
  libvirt_dir="/usr/share/libvirt/networks"
  virsh net-list --all | grep default || virsh net-define ${libvirt_dir}/default.xml
  virsh net-list --all | grep -E "default\s+active" > /dev/null || virsh net-start default
  virsh net-list --all | grep -E "default\s+active\s+yes" > /dev/null || virsh net-autostart --network default

  if [[ -z "$virtual" || "$virtual" == "FALSE" ]]; then
    for network in ${enabled_network_list}; do
      echo "${blue}INFO: Creating Virsh Network: $network & OVS Bridge: ${NET_MAP[$network]}${reset}"
      ovs-vsctl list-br | grep "^${NET_MAP[$network]}$" > /dev/null || ovs-vsctl add-br ${NET_MAP[$network]}
      virsh net-list --all | grep $network > /dev/null || (cat > ${libvirt_dir}/apex-virsh-net.xml && virsh net-define ${libvirt_dir}/apex-virsh-net.xml) << EOF
<network>
  <name>$network</name>
  <forward mode='bridge'/>
  <bridge name='${NET_MAP[$network]}'/>
  <virtualport type='openvswitch'/>
</network>
EOF
      if ! (virsh net-list --all | grep $network > /dev/null); then
          echo "${red}ERROR: unable to create network: ${network}${reset}"
          exit 1;
      fi
      rm -f ${libvirt_dir}/apex-virsh-net.xml &> /dev/null;
      virsh net-list | grep -E "$network\s+active" > /dev/null || virsh net-start $network
      virsh net-list | grep -E "$network\s+active\s+yes" > /dev/null || virsh net-autostart --network $network
    done

    echo -e "${blue}INFO: Bridges set: ${reset}"
    ovs-vsctl list-br

    # bridge interfaces to correct OVS instances for baremetal deployment
    for network in ${enabled_network_list}; do
      if [[ "$network" != "admin_network" && "$network" != "public_network" ]]; then
        continue
      fi
      this_interface=$(eval echo \${${network}_bridged_interface})
      # check if this a bridged interface for this network
      if [[ ! -z "$this_interface" || "$this_interface" != "none" ]]; then
        if ! attach_interface_to_ovs ${NET_MAP[$network]} ${this_interface} ${network}; then
          echo -e "${red}ERROR: Unable to bridge interface ${this_interface} to bridge ${NET_MAP[$network]} for enabled network: ${network}${reset}"
          exit 1
        else
          echo -e "${blue}INFO: Interface ${this_interface} bridged to bridge ${NET_MAP[$network]} for enabled network: ${network}${reset}"
        fi
      else
        echo "${red}ERROR: Unable to determine interface to bridge to for enabled network: ${network}${reset}"
        exit 1
      fi
    done
  else
    for network in ${OPNFV_NETWORK_TYPES}; do
      echo "${blue}INFO: Creating Virsh Network: $network${reset}"
      virsh net-list --all | grep $network > /dev/null || (cat > ${libvirt_dir}/apex-virsh-net.xml && virsh net-define ${libvirt_dir}/apex-virsh-net.xml) << EOF
<network ipv6='yes'>
<name>$network</name>
<bridge name='${NET_MAP[$network]}'/>
</network>
EOF
      if ! (virsh net-list --all | grep $network > /dev/null); then
          echo "${red}ERROR: unable to create network: ${network}${reset}"
          exit 1;
      fi
      rm -f ${libvirt_dir}/apex-virsh-net.xml &> /dev/null;
      virsh net-list | grep -E "$network\s+active" > /dev/null || virsh net-start $network
      virsh net-list | grep -E "$network\s+active\s+yes" > /dev/null || virsh net-autostart --network $network
    done

    echo -e "${blue}INFO: Bridges set: ${reset}"
    brctl show
  fi

  echo -e "${blue}INFO: virsh networks set: ${reset}"
  virsh net-list

  # ensure storage pool exists and is started
  virsh pool-list --all | grep default > /dev/null || virsh pool-define-as --name default dir --target /var/lib/libvirt/images
  virsh pool-list | grep -Eo "default\s+active" > /dev/null || (virsh pool-autostart default; virsh pool-start default)

  if ! egrep '^flags.*(vmx|svm)' /proc/cpuinfo > /dev/null; then
    echo "${red}virtualization extensions not found, kvm kernel module insertion may fail.\n  \
Are you sure you have enabled vmx in your bios or hypervisor?${reset}"
  fi

  if ! lsmod | grep kvm > /dev/null; then modprobe kvm; fi
  if ! lsmod | grep kvm_intel > /dev/null; then modprobe kvm_intel; fi

  if ! lsmod | grep kvm > /dev/null; then
    echo "${red}kvm kernel modules not loaded!${reset}"
    return 1
  fi

  ##sshkeygen for root
  if [ ! -e ~/.ssh/id_rsa.pub ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
  fi

  echo "${blue}All dependencies installed and running${reset}"
}

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
      echo "Found Undercloud VM, using existing VM"
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

##Create virtual nodes in virsh
##params: vcpus, ramsize
function setup_virtual_baremetal {
  local vcpus ramsize
  if [ -z "$1" ]; then
    vcpus=4
    ramsize=8192
  elif [ -z "$2" ]; then
    vcpus=$1
    ramsize=8192
  else
    vcpus=$1
    ramsize=$(($2*1024))
  fi
  #start by generating the opening json for instackenv.json
  cat > $CONFIG/instackenv-virt.json << EOF
{
  "nodes": [
EOF

  # next create the virtual machines and add their definitions to the file
  if [ "$ha_enabled" == "False" ]; then
      # 1 controller + computes
      # zero based so just pass compute count
      vm_index=$VM_COMPUTES
  else
      # 3 controller + computes
      # zero based so add 2 to compute count
      vm_index=$((2+$VM_COMPUTES))
  fi

  for i in $(seq 0 $vm_index); do
    if ! virsh list --all | grep baremetal${i} > /dev/null; then
      define_vm baremetal${i} network 41 'admin_network' $vcpus $ramsize
      for n in private_network public_network storage_network api_network; do
        if [[ $enabled_network_list =~ $n ]]; then
          echo -n "$n "
          virsh attach-interface --domain baremetal${i} --type network --source $n --model virtio --config
        fi
      done
    else
      echo "Found Baremetal ${i} VM, using existing VM"
    fi
    #virsh vol-list default | grep baremetal${i} 2>&1> /dev/null || virsh vol-create-as default baremetal${i}.qcow2 41G --format qcow2
    mac=$(virsh domiflist baremetal${i} | grep admin_network | awk '{ print $5 }')

    if [ "$VM_COMPUTES" -gt 0 ]; then
      capability="profile:compute"
      VM_COMPUTES=$((VM_COMPUTES - 1))
    else
      capability="profile:control"
    fi

    cat >> $CONFIG/instackenv-virt.json << EOF
    {
      "pm_addr": "192.168.122.1",
      "pm_user": "root",
      "pm_password": "INSERT_STACK_USER_PRIV_KEY",
      "pm_type": "pxe_ssh",
      "mac": [
        "$mac"
      ],
      "cpu": "$vcpus",
      "memory": "$ramsize",
      "disk": "41",
      "arch": "x86_64",
      "capabilities": "$capability"
    },
EOF
  done

  #truncate the last line to remove the comma behind the bracket
  tail -n 1 $CONFIG/instackenv-virt.json | wc -c | xargs -I {} truncate $CONFIG/instackenv-virt.json -s -{}

  #finally reclose the bracket and close the instackenv.json file
  cat >> $CONFIG/instackenv-virt.json << EOF
    }
  ],
  "arch": "x86_64",
  "host-ip": "192.168.122.1",
  "power_manager": "nova.virt.baremetal.virtual_power_driver.VirtualPowerManager",
  "seed-ip": "",
  "ssh-key": "INSERT_STACK_USER_PRIV_KEY",
  "ssh-user": "root"
}
EOF
  #Overwrite the tripleo-inclubator domain.xml with our own, keeping a backup.
  if [ ! -f /usr/share/tripleo/templates/domain.xml.bak ]; then
    /usr/bin/mv -f /usr/share/tripleo/templates/domain.xml /usr/share/tripleo/templates/domain.xml.bak
  fi

  /usr/bin/cp -f $LIB/installer/domain.xml /usr/share/tripleo/templates/domain.xml
}

##Create virtual nodes in virsh
##params: name - String: libvirt name for VM
##        bootdev - String: boot device for the VM
##        disksize - Number: size of the disk in GB
##        ovs_bridges: - List: list of ovs bridges
##        vcpus - Number of VCPUs to use (defaults to 4)
##        ramsize - Size of RAM for VM in MB (defaults to 8192)
function define_vm () {
  local vcpus ramsize

  if [ -z "$5" ]; then
    vcpus=4
    ramsize=8388608
  elif [ -z "$6" ]; then
    vcpus=$5
    ramsize=8388608
  else
    vcpus=$5
    ramsize=$(($6*1024))
  fi

  # Create the libvirt storage volume
  if virsh vol-list default | grep ${1}.qcow2 2>&1> /dev/null; then
    volume_path=$(virsh vol-path --pool default ${1}.qcow2 || echo "/var/lib/libvirt/images/${1}.qcow2")
    echo "Volume ${1} exists. Deleting Existing Volume $volume_path"
    virsh vol-dumpxml ${1}.qcow2 --pool default > /dev/null || echo '' #ok for this to fail
    touch $volume_path
    virsh vol-delete ${1}.qcow2 --pool default
  fi
  virsh vol-create-as default ${1}.qcow2 ${3}G --format qcow2
  volume_path=$(virsh vol-path --pool default ${1}.qcow2)
  if [ ! -f $volume_path ]; then
      echo "$volume_path Not created successfully... Aborting"
      exit 1
  fi

  # create the VM
  /usr/libexec/openstack-tripleo/configure-vm --name $1 \
                                              --bootdev $2 \
                                              --image "$volume_path" \
                                              --diskbus sata \
                                              --arch x86_64 \
                                              --cpus $vcpus \
                                              --memory $ramsize \
                                              --libvirt-nic-driver virtio \
                                              --baremetal-interface $4
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

      DEPLOY_OPTIONS+=" --libvirt-type qemu"
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
sudo systemctl restart openstack-nova-conductor
sudo systemctl restart openstack-nova-compute

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

##preping it for deployment and launch the deploy
##params: none
function undercloud_prep_overcloud_deploy {
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

##Post configuration after install
##params: none
function configure_post_install {
  local opnfv_attach_networks ovs_ip ip_range net_cidr tmp_ip
  opnfv_attach_networks="admin_network public_network"

  echo -e "${blue}INFO: Post Install Configuration Running...${reset}"

  echo -e "${blue}INFO: Configuring ssh for root to overcloud nodes...${reset}"
  # copy host key to instack
  scp ${SSH_OPTIONS[@]} /root/.ssh/id_rsa.pub "stack@$UNDERCLOUD":jumphost_id_rsa.pub

  # add host key to overcloud nodes authorized keys
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
source stackrc
nodes=\$(nova list | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
for node in \$nodes; do
cat ~/jumphost_id_rsa.pub | ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" 'cat >> ~/.ssh/authorized_keys'
done
EOI

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source overcloudrc
set -o errexit
echo "Configuring Neutron external network"
neutron net-create external --router:external=True --tenant-id \$(openstack project show service | grep id | awk '{ print \$4 }')
neutron subnet-create --name external-net --tenant-id \$(openstack project show service | grep id | awk '{ print \$4 }') --disable-dhcp external --gateway ${public_network_gateway} --allocation-pool start=${public_network_floating_ip_range%%,*},end=${public_network_floating_ip_range##*,} ${public_network_cidr}

echo "Removing sahara endpoint and service"
sahara_service_id=\$(openstack service list | grep sahara | cut -d ' ' -f 2)
sahara_endpoint_id=\$(openstack endpoint list | grep sahara | cut -d ' ' -f 2)
openstack endpoint delete \$sahara_endpoint_id
openstack service delete \$sahara_service_id

echo "Removing swift endpoint and service"
swift_service_id=\$(openstack service list | grep swift | cut -d ' ' -f 2)
swift_endpoint_id=\$(openstack endpoint list | grep swift | cut -d ' ' -f 2)
openstack endpoint delete \$swift_endpoint_id
openstack service delete \$swift_service_id

if [ "${deploy_options_array['congress']}" == 'True' ]; then
    for s in nova neutronv2 ceilometer cinder glancev2 keystone; do
        openstack congress datasource create \$s "\$s" \\
            --config username=\$OS_USERNAME \\
            --config tenant_name=\$OS_TENANT_NAME \\
            --config password=\$OS_PASSWORD \\
            --config auth_url=\$OS_AUTH_URL
    done
fi
EOI

  echo -e "${blue}INFO: Checking if OVS bridges have IP addresses...${reset}"
  for network in ${opnfv_attach_networks}; do
    ovs_ip=$(find_ip ${NET_MAP[$network]})
    tmp_ip=''
    if [ -n "$ovs_ip" ]; then
      echo -e "${blue}INFO: OVS Bridge ${NET_MAP[$network]} has IP address ${ovs_ip}${reset}"
    else
      echo -e "${blue}INFO: OVS Bridge ${NET_MAP[$network]} missing IP, will configure${reset}"
      # use last IP of allocation pool
      eval "ip_range=\${${network}_usable_ip_range}"
      ovs_ip=${ip_range##*,}
      eval "net_cidr=\${${network}_cidr}"
      sudo ip addr add ${ovs_ip}/${net_cidr##*/} dev ${NET_MAP[$network]}
      sudo ip link set up ${NET_MAP[$network]}
      tmp_ip=$(find_ip ${NET_MAP[$network]})
      if [ -n "$tmp_ip" ]; then
        echo -e "${blue}INFO: OVS Bridge ${NET_MAP[$network]} IP set: ${tmp_ip}${reset}"
        continue
      else
        echo -e "${red}ERROR: Unable to set OVS Bridge ${NET_MAP[$network]} with IP: ${ovs_ip}${reset}"
        return 1
      fi
    fi
  done

  # for virtual, we NAT public network through Undercloud
  if [ "$virtual" == "TRUE" ]; then
    if ! configure_undercloud_nat ${public_network_cidr}; then
      echo -e "${red}ERROR: Unable to NAT undercloud with external net: ${public_network_cidr}${reset}"
      exit 1
    else
      echo -e "${blue}INFO: Undercloud VM has been setup to NAT Overcloud public network${reset}"
    fi
  fi

  # for sfc deployments we need the vxlan workaround
  if [ "${deploy_options_array['sfc']}" == 'True' ]; then
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source stackrc
set -o errexit
for node in \$(nova list | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"); do
ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
sudo ifconfig br-int up
sudo ip route add 123.123.123.0/24 dev br-int
EOF
done
EOI
  fi

  # Collect deployment logs
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
mkdir -p ~/deploy_logs
rm -rf deploy_logs/*
source stackrc
set -o errexit
for node in \$(nova list | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"); do
 ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
 sudo cp /var/log/messages /home/heat-admin/messages.log
 sudo chown heat-admin /home/heat-admin/messages.log
EOF
scp ${SSH_OPTIONS[@]} heat-admin@\$node:/home/heat-admin/messages.log ~/deploy_logs/\$node.messages.log
if [ "$debug" == "TRUE" ]; then
    nova list --ip \$node
    echo "---------------------------"
    echo "-----/var/log/messages-----"
    echo "---------------------------"
    cat ~/deploy_logs/\$node.messages.log
    echo "---------------------------"
    echo "----------END LOG----------"
    echo "---------------------------"
fi
 ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
 sudo rm -f /home/heat-admin/messages.log
EOF
done

# Print out the undercloud IP and dashboard URL
source stackrc
echo "Undercloud IP: $UNDERCLOUD, please connect by doing 'opnfv-util undercloud'"
echo "Overcloud dashboard available at http://\$(heat output-show overcloud PublicVip | sed 's/"//g')/dashboard"
EOI

}

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   -d|--deploy-settings : Full path to deploy settings yaml file. Optional.  Defaults to null"
  echo -e "   -i|--inventory : Full path to inventory yaml file. Required only for baremetal"
  echo -e "   -n|--net-settings : Full path to network settings file. Optional."
  echo -e "   -p|--ping-site : site to use to verify IP connectivity. Optional. Defaults to 8.8.8.8"
  echo -e "   -v|--virtual : Virtualize overcloud nodes instead of using baremetal."
  echo -e "   --flat : disable Network Isolation and use a single flat network for the underlay network."
  echo -e "   --no-post-config : disable Post Install configuration."
  echo -e "   --debug : enable debug output."
  echo -e "   --interactive : enable interactive deployment mode which requires user to confirm steps of deployment."
  echo -e "   --virtual-cpus : Number of CPUs to use per Overcloud VM in a virtual deployment (defaults to 4)."
  echo -e "   --virtual-ram : Amount of RAM to use per Overcloud VM in GB (defaults to 8)."
}

##translates the command line parameters into variables
##params: $@ the entire command line is passed
##usage: parse_cmd_line() "$@"
parse_cmdline() {
  echo -e "\n\n${blue}This script is used to deploy the Apex Installer and Provision OPNFV Target System${reset}\n\n"
  echo "Use -h to display help"
  sleep 2

  while [ "${1:0:1}" = "-" ]
  do
    case "$1" in
        -h|--help)
                display_usage
                exit 0
            ;;
        -d|--deploy-settings)
                DEPLOY_SETTINGS_FILE=$2
                echo "Deployment Configuration file: $2"
                shift 2
            ;;
        -i|--inventory)
                INVENTORY_FILE=$2
                shift 2
            ;;
        -n|--net-settings)
                NETSETS=$2
                echo "Network Settings Configuration file: $2"
                shift 2
            ;;
        -p|--ping-site)
                ping_site=$2
                echo "Using $2 as the ping site"
                shift 2
            ;;
        -v|--virtual)
                virtual="TRUE"
                echo "Executing a Virtual Deployment"
                shift 1
            ;;
        --flat )
                net_isolation_enabled="FALSE"
                echo "Underlay Network Isolation Disabled: using flat configuration"
                shift 1
            ;;
        --no-post-config )
                post_config="FALSE"
                echo "Post install configuration disabled"
                shift 1
            ;;
        --debug )
                debug="TRUE"
                echo "Enable debug output"
                shift 1
            ;;
        --interactive )
                interactive="TRUE"
                echo "Interactive mode enabled"
                shift 1
            ;;
        --virtual-cpus )
                VM_CPUS=$2
                echo "Number of CPUs per VM set to $VM_CPUS"
                shift 2
            ;;
        --virtual-ram )
                VM_RAM=$2
                echo "Amount of RAM per VM set to $VM_RAM"
                shift 2
            ;;
        --virtual-computes )
                VM_COMPUTES=$2
                echo "Virtual Compute nodes set to $VM_COMPUTES"
                shift 2
            ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done

  if [[ ! -z "$NETSETS" && "$net_isolation_enabled" == "FALSE" ]]; then
    echo -e "${red}INFO: Single flat network requested. Only admin_network settings will be used!${reset}"
  elif [[ -z "$NETSETS" ]]; then
    echo -e "${red}ERROR: You must provide a network_settings file with -n.${reset}"
    exit 1
  fi

  if [[ -n "$virtual" && -n "$INVENTORY_FILE" ]]; then
    echo -e "${red}ERROR: You should not specify an inventory with virtual deployments${reset}"
    exit 1
  fi

  if [[ -z "$DEPLOY_SETTINGS_FILE" || ! -f "$DEPLOY_SETTINGS_FILE" ]]; then
    echo -e "${red}ERROR: Deploy Settings: ${DEPLOY_SETTINGS_FILE} does not exist! Exiting...${reset}"
    exit 1
  fi

  if [[ ! -z "$NETSETS" && ! -f "$NETSETS" ]]; then
    echo -e "${red}ERROR: Network Settings: ${NETSETS} does not exist! Exiting...${reset}"
    exit 1
  fi

  if [[ ! -z "$INVENTORY_FILE" && ! -f "$INVENTORY_FILE" ]]; then
    echo -e "{$red}ERROR: Inventory File: ${INVENTORY_FILE} does not exist! Exiting...${reset}"
    exit 1
  fi

  if [[ -z "$virtual" && -z "$INVENTORY_FILE" ]]; then
    echo -e "${red}ERROR: You must specify an inventory file for baremetal deployments! Exiting...${reset}"
    exit 1
  fi

  if [[ "$net_isolation_enabled" == "FALSE" && "$post_config" == "TRUE" ]]; then
    echo -e "${blue}INFO: Post Install Configuration will be skipped.  It is not supported with --flat${reset}"
    post_config="FALSE"
  fi

}

##END FUNCTIONS

main() {
  parse_cmdline "$@"
  echo -e "${blue}INFO: Parsing network settings file...${reset}"
  parse_network_settings
  if ! configure_deps; then
    echo -e "${red}Dependency Validation Failed, Exiting.${reset}"
    exit 1
  fi
  if [ -n "$DEPLOY_SETTINGS_FILE" ]; then
    echo -e "${blue}INFO: Parsing deploy settings file...${reset}"
    parse_deploy_settings
  fi
  setup_undercloud_vm
  if [ "$virtual" == "TRUE" ]; then
    setup_virtual_baremetal $VM_CPUS $VM_RAM
  elif [ -n "$INVENTORY_FILE" ]; then
    parse_inventory_file
  fi
  configure_undercloud
  undercloud_prep_overcloud_deploy
  if [ "$post_config" == "TRUE" ]; then
    if ! configure_post_install; then
      echo -e "${red}ERROR:Post Install Configuration Failed, Exiting.${reset}"
      exit 1
    else
      echo -e "${blue}INFO: Post Install Configuration Complete${reset}"
    fi
  fi
  if [[ "${deploy_options_array['sdn_controller']}" == 'onos' ]]; then
    if ! onos_update_gw_mac ${public_network_cidr} ${public_network_gateway}; then
      echo -e "${red}ERROR:ONOS Post Install Configuration Failed, Exiting.${reset}"
      exit 1
    else
      echo -e "${blue}INFO: ONOS Post Install Configuration Complete${reset}"
    fi
  fi
}

main "$@"
