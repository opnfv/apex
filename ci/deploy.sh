#!/bin/bash

# Deploy script to install provisioning server for OPNFV Apex
# author: Dan Radez (dradez@redhat.com)
# author: Tim Rozet (trozet@redhat.com)
#
# Based on RDO Manager http://www.rdoproject.org

set -e

##VARIABLES
if [ "$TERM" != "unknown" ]; then
  reset=$(tput sgr0)
  blue=$(tput setaf 4)
  red=$(tput setaf 1)
  green=$(tput setaf 2)
else
  reset=""
  blue=""
  red=""
  green=""
fi

vm_index=4
ha_enabled="TRUE"
ping_site="8.8.8.8"
ntp_server="pool.ntp.org"
net_isolation_enabled="TRUE"
post_config="TRUE"

declare -i CNT
declare UNDERCLOUD
declare -A deploy_options_array
declare -A NET_MAP

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
DEPLOY_OPTIONS=""
RESOURCES=/var/opt/opnfv/stack
CONFIG=/var/opt/opnfv
INSTACKENV=$CONFIG/instackenv.json
OPNFV_NETWORK_TYPES="admin_network private_network public_network storage_network"
# Netmap used to map networks to OVS bridge names
NET_MAP['admin_network']="brbm"
NET_MAP['private_network']="brbm1"
NET_MAP['public_network']="brbm2"
NET_MAP['storage_network']="brbm3"

##LIBRARIES
source $CONFIG/lib/common-functions.sh
source $CONFIG/lib/installer/onos/onos_gw_mac_update.sh

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
    elif [ "${network}" == 'public_network' ]; then
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
    if [ -n $(eval echo \${${network}_optional_settings}) ]; then
      eval "network_specific_settings=\${${enabled_network}_optional_settings}"
      for setting in ${network_specific_settings}; do
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
    fi
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
      if [[ $inventory_list != *"$this_node"* ]]; then
        inventory_list+="$this_node "
      fi
    fi
  done

  inventory_list=$(echo $inventory_list | sed 's/ $//')

  for node in $inventory_list; do
    ((node_count+=1))
  done

  node_total=$node_count

  if [[ "$node_total" -lt 5 && ha_enabled == "TRUE" ]]; then
    echo -e "${red}ERROR: You must provide at least 5 nodes for HA baremetal deployment${reset}"
    exit 1
  elif [[ "$node_total" -lt 2 ]]; then
    echo -e "${red}ERROR: You must provide at least 2 nodes for non-HA baremetal deployment${reset}"
    exit 1
  fi

  eval $(parse_yaml $INVENTORY_FILE)

  instack_env_output="
{
 \"nodes\" : [

"
  node_count=0
  for node in $inventory_list; do
    ((node_count+=1))
    node_output="
        {
          \"pm_password\": \"$(eval echo \${${node}ipmi_pass})\",
          \"pm_type\": \"pxe_ipmitool\",
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
    instack_env_output+=${node_output}
    if [ $node_count -lt $node_total ]; then
      instack_env_output+="        },"
    else
      instack_env_output+="        }"
    fi
  done

  instack_env_output+='
  ]
}
'
  #Copy instackenv.json to undercloud for baremetal
  echo -e "{blue}Parsed instackenv JSON:\n${instack_env_output}${reset}"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
cat > instackenv.json << EOF
$instack_env_output
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
  systemctl start openvswitch

  # If flat we only use admin network
  if [[ "$net_isolation_enabled" == "FALSE" ]]; then
    virsh_enabled_networks="admin_network"
  # For baremetal we only need to create/attach instack to admin and public
  elif [ "$virtual" == "FALSE" ]; then
    virsh_enabled_networks="admin_network public_network"
  else
    virsh_enabled_networks=$enabled_network_list
  fi

  for network in ${OPNFV_NETWORK_TYPES}; do
    ovs-vsctl list-br | grep ${NET_MAP[$network]} > /dev/null || ovs-vsctl add-br ${NET_MAP[$network]}
    virsh net-list --all | grep ${NET_MAP[$network]} > /dev/null || virsh net-create $CONFIG/${NET_MAP[$network]}-net.xml
    virsh net-list | grep -E "${NET_MAP[$network]}\s+active" > /dev/null || virsh net-start ${NET_MAP[$network]}
  done

  echo -e "${blue}INFO: Bridges set: ${reset}"
  ovs-vsctl list-br
  echo -e "${blue}INFO: virsh networks set: ${reset}"
  virsh net-list

  if [[ -z "$virtual" || "$virtual" == "FALSE" ]]; then
    # bridge interfaces to correct OVS instances for baremetal deployment
    for network in ${enabled_network_list}; do
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
  virsh pool-list --all | grep default > /dev/null || virsh pool-create $CONFIG/default-pool.xml
  virsh pool-list | grep -Eo "default\s+active" > /dev/null || virsh pool-start default

  if virsh net-list | grep default > /dev/null; then
    num_ints_same_subnet=$(ip addr show | grep "inet 192.168.122" | wc -l)
    if [ "$num_ints_same_subnet" -gt 1 ]; then
      virsh net-destroy default
      ##go edit /etc/libvirt/qemu/networks/default.xml
      sed -i 's/192.168.122/192.168.123/g' /etc/libvirt/qemu/networks/default.xml
      sed -i 's/192.168.122/192.168.123/g' instackenv-virt.json
      sleep 5
      virsh net-start default
      virsh net-autostart default
    fi
  fi

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
function setup_instack_vm {
  if ! virsh list --all | grep instack > /dev/null; then
      #virsh vol-create default instack.qcow2.xml
      virsh define $CONFIG/instack.xml

      #Upload instack image
      #virsh vol-create default --file instack.qcow2.xml
      virsh vol-create-as default instack.qcow2 30G --format qcow2

      ### this doesn't work for some reason I was getting hangup events so using cp instead
      #virsh vol-upload --pool default --vol instack.qcow2 --file $CONFIG/stack/instack.qcow2
      #2015-12-05 12:57:20.569+0000: 8755: info : libvirt version: 1.2.8, package: 16.el7_1.5 (CentOS BuildSystem <http://bugs.centos.org>, 2015-11-03-13:56:46, worker1.bsys.centos.org)
      #2015-12-05 12:57:20.569+0000: 8755: warning : virKeepAliveTimerInternal:143 : No response from client 0x7ff1e231e630 after 6 keepalive messages in 35 seconds
      #2015-12-05 12:57:20.569+0000: 8756: warning : virKeepAliveTimerInternal:143 : No response from client 0x7ff1e231e630 after 6 keepalive messages in 35 seconds
      #error: cannot close volume instack.qcow2
      #error: internal error: received hangup / error event on socket
      #error: Reconnected to the hypervisor

      instack_dst=/var/lib/libvirt/images/instack.qcow2
      cp -f $RESOURCES/instack.qcow2 $instack_dst

      # resize instack machine
      echo "Checking if instack needs to be resized..."
      instack_size=$(LIBGUESTFS_BACKEND=direct virt-filesystems --long -h --all -a $instack_dst |grep device | grep -Eo "[0-9\.]+G" | sed -n 's/\([0-9][0-9]*\).*/\1/p')
      if [ "$instack_size" -lt 30 ]; then
        qemu-img resize /var/lib/libvirt/images/instack.qcow2 +25G
	LIBGUESTFS_BACKEND=direct virt-resize --expand /dev/sda1 $RESOURCES/instack.qcow2 $instack_dst
	LIBGUESTFS_BACKEND=direct virt-customize -a $instack_dst --run-command 'xfs_growfs -d /dev/sda1 || true'
        new_size=$(LIBGUESTFS_BACKEND=direct virt-filesystems --long -h --all -a $instack_dst |grep filesystem | grep -Eo "[0-9\.]+G" | sed -n 's/\([0-9][0-9]*\).*/\1/p')
        if [ "$new_size" -lt 30 ]; then
          echo "Error resizing instack machine, disk size is ${new_size}"
          exit 1
        else
          echo "instack successfully resized"
        fi
      else
        echo "skipped instack resize, upstream is large enough"
      fi

  else
      echo "Found Instack VM, using existing VM"
  fi

  # if the VM is not running update the authkeys and start it
  if ! virsh list | grep instack > /dev/null; then
    echo "Injecting ssh key to instack VM"
    virt-customize -c qemu:///system -d instack --run-command "mkdir /root/.ssh/" \
        --upload ~/.ssh/id_rsa.pub:/root/.ssh/authorized_keys \
        --run-command "chmod 600 /root/.ssh/authorized_keys && restorecon /root/.ssh/authorized_keys" \
        --run-command "cp /root/.ssh/authorized_keys /home/stack/.ssh/" \
        --run-command "chown stack:stack /home/stack/.ssh/authorized_keys && chmod 600 /home/stack/.ssh/authorized_keys"
    virsh start instack
  fi

  sleep 3 # let DHCP happen

  CNT=10
  echo -n "${blue}Waiting for instack's dhcp address${reset}"
  while ! grep instack /var/lib/libvirt/dnsmasq/default.leases > /dev/null && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 3
      CNT=CNT-1
  done

  # get the instack VM IP
  UNDERCLOUD=$(grep instack /var/lib/libvirt/dnsmasq/default.leases | awk '{print $3}' | head -n 1)
  if [ -z "$UNDERCLOUD" ]; then
    #if not found then dnsmasq may be using leasefile-ro
    instack_mac=$(virsh domiflist instack | grep default | \
                  grep -Eo "[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+")
    UNDERCLOUD=$(/usr/sbin/arp -e | grep ${instack_mac} | awk {'print $1'})

    if [ -z "$UNDERCLOUD" ]; then
      echo "\n\nNever got IP for Instack. Can Not Continue."
      exit 1
    else
      echo -e "${blue}\rInstack VM has IP $UNDERCLOUD${reset}"
    fi
  else
     echo -e "${blue}\rInstack VM has IP $UNDERCLOUD${reset}"
  fi

  CNT=10
  echo -en "${blue}\rValidating instack VM connectivity${reset}"
  while ! ping -c 1 $UNDERCLOUD > /dev/null && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 3
      CNT=$CNT-1
  done
  if [ "$CNT" -eq 0 ]; then
      echo "Failed to contact Instack. Can Not Continue"
      exit 1
  fi
  CNT=10
  while ! ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "echo ''" 2>&1> /dev/null && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 3
      CNT=$CNT-1
  done
  if [ "$CNT" -eq 0 ]; then
      echo "Failed to connect to Instack. Can Not Continue"
      exit 1
  fi

  # extra space to overwrite the previous connectivity output
  echo -e "${blue}\r                                                                 ${reset}"

  #add the instack public interface if net isolation is enabled (more than just admin network)
  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
    virsh attach-interface --domain instack --type network --source ${NET_MAP['public_network']} --model rtl8139 --config --live
    sleep 1
    ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "if ! ip a s eth2 | grep ${public_network_provisioner_ip} > /dev/null; then ip a a ${public_network_provisioner_ip}/${public_network_cidr##*/} dev eth2; ip link set up dev eth2; fi"
  fi
  # ssh key fix for stack user
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "restorecon -r /home/stack"
}

##Create virtual nodes in virsh
##params: none
function setup_virtual_baremetal {
  for i in $(seq 0 $vm_index); do
    if ! virsh list --all | grep baremetalbrbm_brbm1_brbm2_brbm3_${i} > /dev/null; then
      if [ ! -e $CONFIG/baremetalbrbm_brbm1_brbm2_brbm3_${i}.xml ]; then
        define_virtual_node baremetalbrbm_brbm1_brbm2_brbm3_${i}
      fi
      # Fix for ramdisk using wrong pxeboot interface
      # TODO: revisit this and see if there's a more proper fix
      sed -i "/^\s*<source network='brbm2'\/>/{
        N
        s/^\(.*\)virtio\(.*\)$/\1rtl8139\2/
        }" $CONFIG/baremetalbrbm_brbm1_brbm2_brbm3_${i}.xml
      virsh define $CONFIG/baremetalbrbm_brbm1_brbm2_brbm3_${i}.xml
    else
      echo "Found Baremetal ${i} VM, using existing VM"
    fi
    virsh vol-list default | grep baremetalbrbm_brbm1_brbm2_brbm3_${i} 2>&1> /dev/null || virsh vol-create-as default baremetalbrbm_brbm1_brbm2_brbm3_${i}.qcow2 40G --format qcow2
  done

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

  # set nics appropriately
  sed -i 's#^.*Compute::Net::SoftwareConfig:.*$#  OS::TripleO::Compute::Net::SoftwareConfig: nics/compute'${nic_ext}'.yaml#' $1
  sed -i 's#^.*Controller::Net::SoftwareConfig:.*$#  OS::TripleO::Controller::Net::SoftwareConfig: nics/controller'${nic_ext}'.yaml#' $1
}
##Copy over the glance images and instack json file
##params: none
function configure_undercloud {

  echo
  echo "Copying configuration file and disk images to instack"
  scp ${SSH_OPTIONS[@]} $RESOURCES/overcloud-full.qcow2 "stack@$UNDERCLOUD":
  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
    configure_network_environment $CONFIG/network-environment.yaml
    echo -e "${blue}Network Environment set for Deployment: ${reset}"
    cat $CONFIG/network-environment.yaml
    scp ${SSH_OPTIONS[@]} $CONFIG/network-environment.yaml "stack@$UNDERCLOUD":
  fi
  scp ${SSH_OPTIONS[@]} -r $CONFIG/nics/ "stack@$UNDERCLOUD":

  # ensure stack user on instack machine has an ssh key
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "if [ ! -e ~/.ssh/id_rsa.pub ]; then ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa; fi"

  if [ "$virtual" == "TRUE" ]; then

      # copy the instack vm's stack user's pub key to
      # root's auth keys so that instack can control
      # vm power on the hypervisor
      ssh ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "cat /home/stack/.ssh/id_rsa.pub" >> /root/.ssh/authorized_keys

      # fix MACs to match new setup
      for i in $(seq 0 $vm_index); do
        pyscript="import json
data = json.load(open('$CONFIG/instackenv-virt.json'))
print data['nodes'][$i]['mac'][0]"

        old_mac=$(python -c "$pyscript")
        new_mac=$(virsh dumpxml baremetalbrbm_brbm1_brbm2_brbm3_$i | grep "mac address" | cut -d = -f2 | grep -Eo "[0-9a-f:]+")
        # this doesn't work with multiple vnics on the vms
        #if [ "$old_mac" != "$new_mac" ]; then
        #  echo "${blue}Modifying MAC for node from $old_mac to ${new_mac}${reset}"
        #  sed -i 's/'"$old_mac"'/'"$new_mac"'/' $CONFIG/instackenv-virt.json
        #fi
      done

      DEPLOY_OPTIONS+=" --libvirt-type qemu"
      INSTACKENV=$CONFIG/instackenv-virt.json

      # upload instackenv file to Instack for virtual deployment
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
  echo "Logging undercloud configuration to instack:/home/stack/apex-undercloud-install.log"
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

openstack undercloud install &> apex-undercloud-install.log
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

  if [[ ${#deploy_options_array[@]} -eq 0 || ${deploy_options_array['sdn_controller']} == 'opendaylight' ]]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight.yaml"
  elif [ ${deploy_options_array['sdn_controller']} == 'opendaylight-external' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight-external.yaml"
  elif [ ${deploy_options_array['sdn_controller']} == 'onos' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/onos.yaml"
  elif [ ${deploy_options_array['sdn_controller']} == 'opencontrail' ]; then
    echo -e "${red}ERROR: OpenContrail is currently unsupported...exiting${reset}"
    exit 1
  fi

  # make sure ceph is installed
  DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml"

  # check if HA is enabled
  if [[ "$ha_enabled" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --control-scale 3 --compute-scale 2"
     DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml"
  fi

  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
     #DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml"
     DEPLOY_OPTIONS+=" -e network-environment.yaml"
  fi

  if [[ "$ha_enabled" == "TRUE" ]] || [[ "$net_isolation_enabled" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --ntp-server $ntp_server"
  fi

  if [[ ! "$virtual" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --control-flavor control --compute-flavor compute"
  fi

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source stackrc
set -o errexit
echo "Uploading overcloud glance images"
openstack overcloud image upload
echo "Configuring undercloud and discovering nodes"
openstack baremetal import --json instackenv.json
openstack baremetal configure boot
openstack baremetal introspection bulk start
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
openstack overcloud deploy --templates $DEPLOY_OPTIONS
EOF
openstack overcloud deploy --templates $DEPLOY_OPTIONS
EOI

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
neutron net-create external --router:external=True
neutron subnet-create --name external-net --disable-dhcp external --gateway ${public_network_gateway} --allocation-pool start=${public_network_floating_ip_range%%,*},end=${public_network_floating_ip_range##*,} ${public_network_cidr}
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

  # for virtual, we NAT public network through instack
  if [ "$virtual" == "TRUE" ]; then
    if ! configure_undercloud_nat ${public_network_cidr}; then
      echo -e "${red}ERROR: Unable to NAT undercloud with external net: ${public_network_cidr}${reset}"
      exit 1
    else
      echo -e "${blue}INFO: Undercloud (intack) has been setup to NAT Overcloud public network${reset}"
    fi
  fi
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
        *)
                display_usage
                exit 1
            ;;
    esac
  done

  if [[ ! -z "$NETSETS" && "$net_isolation_enabled" == "FALSE" ]]; then
    echo -e "${red}INFO: Single flat network requested. Ignoring any network settings!${reset}"
  elif [[ -z "$NETSETS" && "$net_isolation_enabled" == "TRUE" ]]; then
    echo -e "${red}ERROR: You must provide a network_settings file with -n or use --flat to force a single flat network{reset}"
    exit 1
  fi

  if [[ -n "$virtual" && -n "$INVENTORY_FILE" ]]; then
    echo -e "${red}ERROR: You should not specify an inventory with virtual deployments${reset}"
    exit 1
  fi

  if [[ ! -z "$DEPLOY_SETTINGS_FILE" && ! -f "$DEPLOY_SETTINGS_FILE" ]]; then
    echo -e "${red}ERROR: ${DEPLOY_SETTINGS_FILE} does not exist! Exiting...${reset}"
    exit 1
  fi

  if [[ ! -z "$NETSETS" && ! -f "$NETSETS" ]]; then
    echo -e "${red}ERROR: ${NETSETS} does not exist! Exiting...${reset}"
    exit 1
  fi

  if [[ ! -z "$INVENTORY_FILE" && ! -f "$INVENTORY_FILE" ]]; then
    echo -e "{$red}ERROR: ${DEPLOY_SETTINGS_FILE} does not exist! Exiting...${reset}"
    exit 1
  fi

  if [[ -z "$virtual" && -z "$INVENTORY_FILE" ]]; then
    echo -e "${red}ERROR: You must specify an inventory file for baremetal deployments! Exiting...${reset}"
    exit 1
  fi
}

##END FUNCTIONS

main() {
  parse_cmdline "$@"
  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
    echo -e "${blue}INFO: Parsing network settings file...${reset}"
    parse_network_settings
  fi
  if ! configure_deps; then
    echo -e "${red}Dependency Validation Failed, Exiting.${reset}"
    exit 1
  fi
  if [ -n "$DEPLOY_SETTINGS_FILE" ]; then
    parse_deploy_settings
  fi
  setup_instack_vm
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
  if [[ ${deploy_options_array['sdn_controller']} == 'onos' ]]; then
    if ! onos_update_gw_mac ${public_network_cidr} ${public_network_gateway}; then
      echo -e "${red}ERROR:ONOS Post Install Configuration Failed, Exiting.${reset}"
      exit 1
    else
      echo -e "${blue}INFO: ONOS Post Install Configuration Complete${reset}"
    fi
  fi
}

main "$@"
