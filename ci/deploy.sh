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

vm_index=4
interactive="FALSE"
ping_site="8.8.8.8"
ntp_server="pool.ntp.org"
net_isolation_enabled="TRUE"
post_config="TRUE"
debug="FALSE"

declare -i CNT
declare UNDERCLOUD
declare -A deploy_options_array
declare -A NET_MAP

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
DEPLOY_OPTIONS=""
RESOURCES=/var/opt/opnfv/images
CONFIG=/var/opt/opnfv
OPNFV_NETWORK_TYPES="admin_network private_network public_network storage_network"
# Netmap used to map networks to OVS bridge names
NET_MAP['admin_network']="br-admin"
NET_MAP['private_network']="br-private"
NET_MAP['public_network']="br-public"
NET_MAP['storage_network']="br-storage"

##FUNCTIONS
##translates yaml into variables
##params: filename, prefix (ex. "config_")
##usage: parse_yaml opnfv_ksgen_settings.yml "config_"
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=%s\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

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
##parses variable from a string with '='
##and removes global prefix
##params: string, prefix
##usage: parse_setting_var 'deploy_myvar=2' 'deploy_'
parse_setting_var() {
  local mystr=$1
  local prefix=$2
  if echo $mystr | grep -E "^.+\=" > /dev/null; then
    echo $(echo $mystr | grep -Eo "^.+\=" | tr -d '=' |  sed 's/^'"$prefix"'//')
  else
    return 1
  fi
}
##parses value from a string with '='
##params: string
##usage: parse_setting_value
parse_setting_value() {
  local mystr=$1
  echo $(echo $mystr | grep -Eo "\=.*$" | tr -d '=')
}
##parses network settings yaml into globals
parse_network_settings() {
  local required_network_settings="cidr"
  local common_optional_network_settings="usable_ip_range"
  local admin_network_optional_settings="provisioner_ip dhcp_range introspection_range"
  local public_network_optional_settings="floating_ip_range gateway provisioner_ip"
  local nic_value cidr

  eval $(parse_yaml ${NETSETS})
  for network in ${OPNFV_NETWORK_TYPES}; do
    if [[ $(eval echo \${${network}_enabled}) == 'true' ]]; then
      enabled_network_list+="${network} "
    elif [ "${network}" == 'admin_network' ]; then
      echo -e "${red}ERROR: You must enable admin_network and configure it explicitly or use auto-detection${reset}"
      exit 1
    elif [[ "${network}" == 'public_network' && "$net_isolation_enabled" == "TRUE" ]]; then
      echo -e "${red}ERROR: You must enable public_network and configure it explicitly or use auto-detection${reset}"
      exit 1
    else
      echo -e "${blue}INFO: Network: ${network} is disabled, will collapse into admin_network"
    fi
  done

  # check for enabled network values
  for enabled_network in ${enabled_network_list}; do
    # detect required settings first to continue
    echo -e "${blue}INFO: Detecting Required settings for: ${enabled_network}${reset}"
    for setting in ${required_network_settings}; do
      eval "setting_value=\${${enabled_network}_${setting}}"
      if [ -z "${setting_value}" ]; then
        # if setting is missing we try to autodetect
        eval "nic_value=\${${enabled_network}_bridged_interface}"
        if [ -n "$nic_value" ]; then
          setting_value=$(eval find_${setting} ${nic_value})
          if [ -n "$setting_value" ]; then
            eval "${enabled_network}_${setting}=${setting_value}"
            echo -e "${blue}INFO: Auto-detection: ${enabled_network}_${setting}: ${setting_value}${reset}"
          else
            echo -e "${red}ERROR: Auto-detection failed: ${setting} not found using interface: ${nic_value}${reset}"
            exit 1
          fi
        else
          echo -e "${red}ERROR: Required setting: ${setting} not found, and bridge interface not provided\
for Auto-detection${reset}"
          exit 1
        fi
      else
        echo -e "${blue}INFO: ${enabled_network}_${setting}: ${setting_value}${reset}"
      fi
    done
    echo -e "${blue}INFO: Detecting Common settings for: ${enabled_network}${reset}"
    # detect optional common settings
    # these settings can be auto-generated if missing
    for setting in ${common_optional_network_settings}; do
      eval "setting_value=\${${enabled_network}_${setting}}"
      if [ -z "${setting_value}" ]; then
        if [ -n "$nic_value" ]; then
          setting_value=$(eval find_${setting} ${nic_value})
        else
          setting_value=''
          echo -e "${blue}INFO: Skipping Auto-detection, NIC not specified for ${enabled_network}.  Attempting Auto-generation...${reset}"
        fi
        if [ -n "$setting_value" ]; then
          eval "${enabled_network}_${setting}=${setting_value}"
          echo -e "${blue}INFO: Auto-detection: ${enabled_network}_${setting}: ${setting_value}${reset}"
        else
          # if Auto-detection fails we can auto-generate with CIDR
          eval "cidr=\${${enabled_network}_cidr}"
          if [ -n "$cidr" ]; then
            echo -e "${blue}INFO: Auto-generating: ${setting}${reset}"
            setting_value=$(eval generate_${setting} ${cidr})
          else
            setting_value=''
            echo -e "${red}ERROR: Auto-generation failed: required parameter CIDR missing for network ${enabled_network}${reset}"
          fi
          if [ -n "$setting_value" ]; then
            eval "${enabled_network}_${setting}=${setting_value}"
            echo -e "${blue}INFO: Auto-generated: ${enabled_network}_${setting}: ${setting_value}${reset}"
          else
            echo -e "${red}ERROR: Auto-generation failed: ${setting} not found${reset}"
            exit 1
          fi
        fi
      else
        echo -e "${blue}INFO: ${enabled_network}_${setting}: ${setting_value}${reset}"
      fi
    done
    echo -e "${blue}INFO: Detecting Network Specific settings for: ${enabled_network}${reset}"
    # detect network specific settings
    for setting in $(eval echo \${${enabled_network}_optional_settings}); do
      eval "setting_value=\${${enabled_network}_${setting}}"
      if [ -z "${setting_value}" ]; then
        if [ -n "$nic_value" ]; then
          setting_value=$(eval find_${setting} ${nic_value})
        else
          setting_value=''
          echo -e "${blue}INFO: Skipping Auto-detection, NIC not specified for ${enabled_network}.  Attempting Auto-generation...${reset}"
        fi
        if [ -n "$setting_value" ]; then
          eval "${enabled_network}_${setting}=${setting_value}"
          echo -e "${blue}INFO: Auto-detection: ${enabled_network}_${setting}: ${setting_value}${reset}"
        else
          eval "cidr=\${${enabled_network}_cidr}"
          if [ -n "$cidr" ]; then
            setting_value=$(eval generate_${setting} ${cidr})
          else
            setting_value=''
            echo -e "${red}ERROR: Auto-generation failed: required parameter CIDR missing for network ${enabled_network}${reset}"
          fi
          if [ -n "$setting_value" ]; then
            eval "${enabled_network}_${setting}=${setting_value}"
            echo -e "${blue}INFO: Auto-generated: ${enabled_network}_${setting}: ${setting_value}${reset}"
          else
            echo -e "${red}ERROR: Auto-generation failed: ${setting} not found${reset}"
            exit 1
          fi
        fi
      else
        echo -e "${blue}INFO: ${enabled_network}_${setting}: ${setting_value}${reset}"
      fi
    done
  done
}
##parses deploy settings yaml into globals and options array
##params: none
##usage:  parse_deploy_settings
parse_deploy_settings() {
  local global_prefix="deploy_global_params_"
  local options_prefix="deploy_deploy_options_"
  local myvar myvalue
  local settings=$(parse_yaml $DEPLOY_SETTINGS_FILE "deploy_")

  for this_setting in $settings; do
    if contains_prefix $this_setting $global_prefix; then
      myvar=$(parse_setting_var $this_setting $global_prefix)
      if [ -z "$myvar" ]; then
        echo -e "${red}ERROR: while parsing ${DEPLOY_SETTINGS_FILE} for setting: ${this_setting}${reset}"
      fi
      myvalue=$(parse_setting_value $this_setting)
      # Do not override variables set by cmdline
      if [ -z "$(eval echo \$$myvar)" ]; then
        eval "$myvar=\$myvalue"
        echo -e "${blue}Global parameter set: ${myvar}:${myvalue}${reset}"
      else
        echo -e "${blue}Global parameter already set: ${myvar}${reset}"
      fi
    elif contains_prefix $this_setting $options_prefix; then
      myvar=$(parse_setting_var $this_setting $options_prefix)
      if [ -z "$myvar" ]; then
        echo -e "${red}ERROR: while parsing ${DEPLOY_SETTINGS_FILE} for setting: ${this_setting}${reset}"
      fi
      myvalue=$(parse_setting_value $this_setting)
      deploy_options_array[$myvar]=$myvalue
      echo -e "${blue}Deploy option set: ${myvar}:${myvalue}${reset}"
    fi
  done
}
##parses baremetal yaml settings into compatible json
##writes the json to $CONFIG/instackenv_tmp.json
##params: none
##usage: parse_inventory_file
parse_inventory_file() {
  local inventory=$(parse_yaml $INVENTORY_FILE)
  local node_list
  local node_prefix="node"
  local node_count=0
  local node_total
  local inventory_list

  # detect number of nodes
  for entry in $inventory; do
    if echo $entry | grep -Eo "^nodes_node[0-9]+_" > /dev/null; then
      this_node=$(echo $entry | grep -Eo "^nodes_node[0-9]+_")
      if [[ "$inventory_list" != *"$this_node"* ]]; then
        inventory_list+="$this_node "
      fi
    fi
  done

  inventory_list=$(echo $inventory_list | sed 's/ $//')

  for node in $inventory_list; do
    ((node_count+=1))
  done

  node_total=$node_count

  if [[ "$node_total" -lt 5 && ( ha_enabled == "TRUE" || "$ha_enabled" == "true" ) ]]; then
    echo -e "${red}ERROR: You must provide at least 5 nodes for HA baremetal deployment${reset}"
    exit 1
  elif [[ "$node_total" -lt 2 ]]; then
    echo -e "${red}ERROR: You must provide at least 2 nodes for non-HA baremetal deployment${reset}"
    exit 1
  fi

  eval $(parse_yaml $INVENTORY_FILE) || {
    echo "${red}Failed to parse inventory.yaml. Aborting.${reset}"
    exit 1
  }

  instackenv_output="
{
 \"nodes\" : [

"
  node_count=0
  for node in $inventory_list; do
    ((node_count+=1))
    node_output="
        {
          \"pm_password\": \"$(eval echo \${${node}ipmi_pass})\",
          \"pm_type\": \"$(eval echo \${${node}pm_type})\",
          \"mac\": [
            \"$(eval echo \${${node}mac_address})\"
          ],
          \"cpu\": \"$(eval echo \${${node}cpus})\",
          \"memory\": \"$(eval echo \${${node}memory})\",
          \"disk\": \"$(eval echo \${${node}disk})\",
          \"arch\": \"$(eval echo \${${node}arch})\",
          \"pm_user\": \"$(eval echo \${${node}ipmi_user})\",
          \"pm_addr\": \"$(eval echo \${${node}ipmi_ip})\",
          \"capabilities\": \"$(eval echo \${${node}capabilities})\"
"
    instackenv_output+=${node_output}
    if [ $node_count -lt $node_total ]; then
      instackenv_output+="        },"
    else
      instackenv_output+="        }"
    fi
  done

  instackenv_output+='
  ]
}
'
  #Copy instackenv.json to undercloud for baremetal
  echo -e "{blue}Parsed instackenv JSON:\n${instackenv_output}${reset}"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
cat > instackenv.json << EOF
$instackenv_output
EOF
EOI

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

  for network in ${OPNFV_NETWORK_TYPES}; do
    echo "${blue}INFO: Creating Virsh Network: $network & OVS Bridge: ${NET_MAP[$network]}${reset}"
    ovs-vsctl list-br | grep ${NET_MAP[$network]} > /dev/null || ovs-vsctl add-br ${NET_MAP[$network]}
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
  echo -e "${blue}INFO: virsh networks set: ${reset}"
  virsh net-list

  if [[ -z "$virtual" || "$virtual" == "FALSE" ]]; then
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
  fi

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
      define_vm undercloud hd 30 "$undercloud_nets"

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
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "if ! ip a s eth2 | grep ${public_network_provisioner_ip} > /dev/null; then ip a a ${public_network_provisioner_ip}/${public_network_cidr##*/} dev eth2; ip link set up dev eth2; fi"

  # ssh key fix for stack user
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "restorecon -r /home/stack"
}

##Create virtual nodes in virsh
##params: none
function setup_virtual_baremetal {
  #start by generating the opening json for instackenv.json
  cat > $CONFIG/instackenv-virt.json << EOF
{
  "nodes": [
EOF

  # next create the virtual machines and add their definitions to the file
  for i in $(seq 0 $vm_index); do
    if ! virsh list --all | grep baremetal${i} > /dev/null; then
      define_vm baremetal${i} network 41 'admin_network'
      for n in private_network public_network storage_network; do
        if [[ $enabled_network_list =~ $n ]]; then
          echo -n "$n "
          virsh attach-interface --domain baremetal${i} --type network --source $n --model rtl8139 --config
        fi
      done
    else
      echo "Found Baremetal ${i} VM, using existing VM"
    fi
    #virsh vol-list default | grep baremetal${i} 2>&1> /dev/null || virsh vol-create-as default baremetal${i}.qcow2 41G --format qcow2
    mac=$(virsh domiflist baremetal${i} | grep admin_network | awk '{ print $5 }')

    cat >> $CONFIG/instackenv-virt.json << EOF
    {
      "pm_addr": "192.168.122.1",
      "pm_user": "root",
      "pm_password": "INSERT_STACK_USER_PRIV_KEY",
      "pm_type": "pxe_ssh",
      "mac": [
        "$mac"
      ],
      "cpu": "2",
      "memory": "8192",
      "disk": "41",
      "arch": "x86_64"
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
}

##Create virtual nodes in virsh
##params: name - String: libvirt name for VM
##        bootdev - String: boot device for the VM
##        disksize - Number: size of the disk in GB
##        ovs_bridges: - List: list of ovs bridges
function define_vm () {
  # Create the libvirt storage volume
  if virsh vol-list default | grep ${1}.qcow2 2>&1> /dev/null; then
    volume_path=$(virsh vol-path --pool default ${1}.qcow2 || echo "/var/lib/libvirt/images/${1}.qcow2")
    echo "Volume ${1} exists. Deleting Existing Volume $volume_path"
    virsh vol-dumpxml ${1}.qcow2 --pool default
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
                                              --cpus 2 \
                                              --memory 8388608 \
                                              --libvirt-nic-driver virtio \
                                              --baremetal-interface $4
}

##Set network-environment settings
##params: network-environment file to edit
function configure_network_environment {
  local tht_dir nic_ext
  tht_dir=/usr/share/openstack-tripleo-heat-templates/network
  nic_ext=''

  sed -i '/ControlPlaneSubnetCidr/c\\  ControlPlaneSubnetCidr: "'${admin_network_cidr##*/}'"' $1
  sed -i '/ControlPlaneDefaultRoute/c\\  ControlPlaneDefaultRoute: '${admin_network_provisioner_ip}'' $1
  sed -i '/ExternalNetCidr/c\\  ExternalNetCidr: '${public_network_cidr}'' $1
  sed -i "/ExternalAllocationPools/c\\  ExternalAllocationPools: [{'start': '${public_network_usable_ip_range%%,*}', 'end': '${public_network_usable_ip_range##*,}'}]" $1
  sed -i '/ExternalInterfaceDefaultRoute/c\\  ExternalInterfaceDefaultRoute: '${public_network_gateway}'' $1
  sed -i '/EC2MetadataIp/c\\  EC2MetadataIp: '${admin_network_provisioner_ip}'' $1

  # check for private network
  if [[ ! -z "$private_network_enabled" && "$private_network_enabled" == "true" ]]; then
      sed -i 's#^.*Network::Tenant.*$#  OS::TripleO::Network::Tenant: '${tht_dir}'/tenant.yaml#' $1
      sed -i 's#^.*Controller::Ports::TenantPort:.*$#  OS::TripleO::Controller::Ports::TenantPort: '${tht_dir}'/ports/tenant.yaml#' $1
      sed -i 's#^.*Compute::Ports::TenantPort:.*$#  OS::TripleO::Compute::Ports::TenantPort: '${tht_dir}'/ports/tenant.yaml#' $1
      sed -i "/TenantAllocationPools/c\\  TenantAllocationPools: [{'start': '${private_network_usable_ip_range%%,*}', 'end': '${private_network_usable_ip_range##*,}'}]" $1
      sed -i '/TenantNetCidr/c\\  TenantNetCidr: '${private_network_cidr}'' $1
      nic_ext+=_private
  else
      sed -i 's#^.*Network::Tenant.*$#  OS::TripleO::Network::Tenant: '${tht_dir}'/noop.yaml#' $1
      sed -i 's#^.*Controller::Ports::TenantPort:.*$#  OS::TripleO::Controller::Ports::TenantPort: '${tht_dir}'/ports/noop.yaml#' $1
      sed -i 's#^.*Compute::Ports::TenantPort:.*$#  OS::TripleO::Compute::Ports::TenantPort: '${tht_dir}'/ports/noop.yaml#' $1
  fi

  # check for storage network
  if [[ ! -z "$storage_network_enabled" && "$storage_network_enabled" == "true" ]]; then
      sed -i 's#^.*Network::Storage.*$#  OS::TripleO::Network::Storage: '${tht_dir}'/storage.yaml#' $1
      sed -i 's#^.*Controller::Ports::StoragePort:.*$#  OS::TripleO::Controller::Ports::StoragePort: '${tht_dir}'/ports/storage.yaml#' $1
      sed -i 's#^.*Compute::Ports::StoragePort:.*$#  OS::TripleO::Compute::Ports::StoragePort: '${tht_dir}'/ports/storage.yaml#' $1
      sed -i "/StorageAllocationPools/c\\  StorageAllocationPools: [{'start': '${storage_network_usable_ip_range%%,*}', 'end': '${storage_network_usable_ip_range##*,}'}]" $1
      sed -i '/StorageNetCidr/c\\  StorageNetCidr: '${storage_network_cidr}'' $1
      nic_ext+=_storage
  else
      sed -i 's#^.*Network::Storage.*$#  OS::TripleO::Network::Storage: '${tht_dir}'/noop.yaml#' $1
      sed -i 's#^.*Controller::Ports::StoragePort:.*$#  OS::TripleO::Controller::Ports::StoragePort: '${tht_dir}'/ports/noop.yaml#' $1
      sed -i 's#^.*Compute::Ports::StoragePort:.*$#  OS::TripleO::Compute::Ports::StoragePort: '${tht_dir}'/ports/noop.yaml#' $1
  fi

  sed -i 's#^.*Controller::Net::SoftwareConfig:.*$#  OS::TripleO::Controller::Net::SoftwareConfig: nics/controller'${nic_ext}'.yaml#' $1

  # check for ODL L3
  if [ "${deploy_options_array['sdn_l3']}" == 'true' ]; then
      nic_ext+=_br-ex_no-public-ip
  fi

  # set nics appropriately
  sed -i 's#^.*Compute::Net::SoftwareConfig:.*$#  OS::TripleO::Compute::Net::SoftwareConfig: nics/compute'${nic_ext}'.yaml#' $1

}
##Copy over the glance images and instackenv json file
##params: none
function configure_undercloud {

  echo
  echo "Copying configuration files to Undercloud"
  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
    configure_network_environment $CONFIG/network-environment.yaml
    echo -e "${blue}Network Environment set for Deployment: ${reset}"
    cat $CONFIG/network-environment.yaml
    scp ${SSH_OPTIONS[@]} $CONFIG/network-environment.yaml "stack@$UNDERCLOUD":
  fi
  scp ${SSH_OPTIONS[@]} -r $CONFIG/nics/ "stack@$UNDERCLOUD":

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
    if [ "${deploy_options_array['sdn_l3']}" == 'true' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_l3.yaml"
    elif [ "${deploy_options_array['sfc']}" == 'true' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_sfc.yaml"
    elif [ "${deploy_options_array['vpn']}" == 'true' ]; then
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight_sdnvpn.yaml"
    else
      DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight.yaml"
    fi
    SDN_IMAGE=opendaylight
    if [ "${deploy_options_array['sfc']}" == 'true' ]; then
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
  elif [[ -z "${deploy_options_array['sdn_controller']}" || "${deploy_options_array['sdn_controller']}" == 'false' ]]; then
    echo -e "${blue}INFO: SDN Controller disabled...will deploy nosdn scenario${reset}"
    SDN_IMAGE=opendaylight
  else
    echo "${red}Invalid sdn_controller: ${deploy_options_array['sdn_controller']}${reset}"
    echo "${red}Valid choices are opendaylight, opendaylight-external, onos, opencontrail, false, or null${reset}"
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
  scp ${SSH_OPTIONS[@]} $RESOURCES/overcloud-full-${SDN_IMAGE}.qcow2 "stack@$UNDERCLOUD":overcloud-full.qcow2

  # make sure ceph is installed
  DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml"

  # scale compute nodes according to inventory
  total_nodes=$(ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "cat /home/stack/instackenv.json | grep -c memory")

  # check if HA is enabled
  if [[ "$ha_enabled" == "TRUE" || "$ha_enabled" == "true" ]]; then
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

  if [[ "$ha_enabled" == "TRUE" || "$ha_enabled" == "true"  ]] || [[ "$net_isolation_enabled" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --ntp-server $ntp_server"
  fi

  if [[ ! "$virtual" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --control-flavor control --compute-flavor compute"
  fi

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
neutron subnet-update \$(neutron subnet-list | grep -v id | grep -v \\\\-\\\\- | awk {'print \$2'}) --dns-nameserver 8.8.8.8
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
set -o errexit
openstack overcloud deploy --templates $DEPLOY_OPTIONS --timeout 90
EOI

  if [ "$debug" == 'TRUE' ]; then
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source overcloudrc
echo "Keystone Endpoint List:"
keystone endpoint-list
echo "Keystone Service List"
keystone service-list
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

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source overcloudrc
set -o errexit
echo "Configuring Neutron external network"
neutron net-create external --router:external=True --tenant-id \$(keystone tenant-get service | grep id | awk '{ print \$4 }')
neutron subnet-create --name external-net --tenant-id \$(keystone tenant-get service | grep id | awk '{ print \$4 }') --disable-dhcp external --gateway ${public_network_gateway} --allocation-pool start=${public_network_floating_ip_range%%,*},end=${public_network_floating_ip_range##*,} ${public_network_cidr}
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
  if [ "${deploy_options_array['sfc']}" == 'true' ]; then
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

# Print out the dashboard URL
source stackrc
echo "Overcloud dashboard available at http://\$(heat output-show overcloud PublicVip | sed 's/"//g')/dashboard"
EOI

}

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   -c|--config : Directory to configuration files. Optional.  Defaults to /var/opt/opnfv/ \n"
  echo -e "   -d|--deploy-settings : Full path to deploy settings yaml file. Optional.  Defaults to null \n"
  echo -e "   -i|--inventory : Full path to inventory yaml file. Required only for baremetal \n"
  echo -e "   -n|--net-settings : Full path to network settings file. Optional. \n"
  echo -e "   -p|--ping-site : site to use to verify IP connectivity. Optional. Defaults to 8.8.8.8 \n"
  echo -e "   -r|--resources : Directory to deployment resources. Optional.  Defaults to /var/opt/opnfv/stack \n"
  echo -e "   -v|--virtual : Virtualize overcloud nodes instead of using baremetal. \n"
  echo -e "   --no-ha : disable High Availability deployment scheme, this assumes a single controller and single compute node \n"
  echo -e "   --flat : disable Network Isolation and use a single flat network for the underlay network.\n"
  echo -e "   --no-post-config : disable Post Install configuration."
  echo -e "   --debug : enable debug output."
  echo -e "   --interactive : enable interactive deployment mode which requires user to confirm steps of deployment."
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
        -c|--config)
                CONFIG=$2
                echo "Deployment Configuration Directory Overridden to: $2"
                shift 2
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
        -r|--resources)
                RESOURCES=$2
                echo "Deployment Resources Directory Overridden to: $2"
                shift 2
            ;;
        -v|--virtual)
                virtual="TRUE"
                echo "Executing a Virtual Deployment"
                shift 1
            ;;
        --no-ha )
                ha_enabled="FALSE"
                vm_index=1
                echo "HA Deployment Disabled"
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

  ##LIBRARIES
  # Do this after cli parse so that $CONFIG is set properly
  source $CONFIG/lib/common-functions.sh
  source $CONFIG/lib/installer/onos/onos_gw_mac_update.sh

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
    parse_deploy_settings
  fi
  setup_undercloud_vm
  if [ "$virtual" == "TRUE" ]; then
    setup_virtual_baremetal
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
