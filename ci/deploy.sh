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

declare -i CNT
declare UNDERCLOUD
declare -A deploy_options_array

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
DEPLOY_OPTIONS=""
RESOURCES=/var/opt/opnfv/stack
CONFIG=/var/opt/opnfv
INSTACKENV=$CONFIG/instackenv.json
NETENV=$CONFIG/network-environment.yaml

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

  # ensure brbm networks are configured
  systemctl start openvswitch
  ovs-vsctl list-br | grep brbm > /dev/null || ovs-vsctl add-br brbm
  virsh net-list --all | grep brbm > /dev/null || virsh net-create $CONFIG/brbm-net.xml
  virsh net-list | grep -E "brbm\s+active" > /dev/null || virsh net-start brbm
  ovs-vsctl list-br | grep brbm1 > /dev/null || ovs-vsctl add-br brbm1
  virsh net-list --all | grep brbm1 > /dev/null || virsh net-create $CONFIG/brbm1-net.xml
  virsh net-list | grep -E "brbm1\s+active" > /dev/null || virsh net-start brbm1

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

      cp -f $RESOURCES/instack.qcow2 /var/lib/libvirt/images/instack.qcow2

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
    UNDERCLOUD=$(arp -e | grep ${instack_mac} | awk {'print $1'})

    if [ -z "$UNDERCLOUD" ]; then
      echo "\n\nNever got IP for Instack. Can Not Continue."
      exit 1
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

  #add the instack brbm1 interface
  virsh attach-interface --domain instack --type network --source brbm1 --model rtl8139 --config --live
  sleep 1
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "if ! ip a s eth2 | grep 192.168.37.1 > /dev/null; then ip a a 192.168.37.1/24 dev eth2; ip link set up dev eth2; fi"

  # ssh key fix for stack user
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "restorecon -r /home/stack"
}

##Create virtual nodes in virsh
##params: none
function setup_virtual_baremetal {
  for i in $(seq 0 $vm_index); do
    if ! virsh list --all | grep baremetalbrbm_brbm1_${i} > /dev/null; then
      if [ ! -e $CONFIG/baremetalbrbm_brbm1_${i}.xml ]; then
        define_virtual_node baremetalbrbm_brbm1_${i}
      fi
      virsh define $CONFIG/baremetalbrbm_brbm1_${i}.xml
    else
      echo "Found Baremetal ${i} VM, using existing VM"
    fi
    virsh vol-list default | grep baremetalbrbm_brbm1_${i} 2>&1> /dev/null || virsh vol-create-as default baremetalbrbm_brbm1_${i}.qcow2 40G --format qcow2
  done

}

##Copy over the glance images and instack json file
##params: none
function configure_undercloud {

  echo
  echo "Copying configuration file and disk images to instack"
  scp ${SSH_OPTIONS[@]} $RESOURCES/overcloud-full.qcow2 "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $NETENV "stack@$UNDERCLOUD":
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
        new_mac=$(virsh dumpxml baremetalbrbm_brbm1_$i | grep "mac address" | cut -d = -f2 | grep -Eo "[0-9a-f:]+")
        # this doesn't work with multiple vnics on the vms
        #if [ "$old_mac" != "$new_mac" ]; then
        #  echo "${blue}Modifying MAC for node from $old_mac to ${new_mac}${reset}"
        #  sed -i 's/'"$old_mac"'/'"$new_mac"'/' $CONFIG/instackenv-virt.json
        #fi
      done

      DEPLOY_OPTIONS+=" --libvirt-type qemu"
      INSTACKENV=$CONFIG/instackenv-virt.json
      NETENV=$CONFIG/network-environment.yaml

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

  # configure undercloud on Undercloud VM
  echo "Running undercloud configuration."
  echo "Logging undercloud configuration to instack:/home/stack/apex-undercloud-install.log"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
if [ -n "$DEPLOY_SETTINGS_FILE" ]; then
  sed -i 's/#local_ip/local_ip/' undercloud.conf
  sed -i 's/#network_gateway/network_gateway/' undercloud.conf
  sed -i 's/#network_cidr/network_cidr/' undercloud.conf
  sed -i 's/#dhcp_start/dhcp_start/' undercloud.conf
  sed -i 's/#dhcp_end/dhcp_end/' undercloud.conf
  sed -i 's/#inspection_iprange/inspection_iprange/' undercloud.conf
  sed -i 's/#undercloud_debug/undercloud_debug/' undercloud.conf

  openstack-config --set undercloud.conf DEFAULT local_ip ${deploy_options_array['instack_ip']}/${deploy_options_array['provisioning_cidr']##*/}
  openstack-config --set undercloud.conf DEFAULT network_gateway ${deploy_options_array['provisioning_gateway']}
  openstack-config --set undercloud.conf DEFAULT network_cidr ${deploy_options_array['provisioning_cidr']}
  openstack-config --set undercloud.conf DEFAULT dhcp_start ${deploy_options_array['provisioning_dhcp_start']}
  openstack-config --set undercloud.conf DEFAULT dhcp_end ${deploy_options_array['provisioning_dhcp_end']}
  openstack-config --set undercloud.conf DEFAULT inspection_iprange ${deploy_options_array['provisioning_inspection_iprange']}
  openstack-config --set undercloud.conf DEFAULT undercloud_debug false

  if [ -n "$net_isolation_enabled" ]; then
    sed -i '/ControlPlaneSubnetCidr/c\\  ControlPlaneSubnetCidr: "${deploy_options_array['provisioning_cidr']##*/}"' network-environment.yaml
    sed -i '/ControlPlaneDefaultRoute/c\\  ControlPlaneDefaultRoute: ${deploy_options_array['provisioning_gateway']}' network-environment.yaml
    sed -i '/ExternalNetCidr/c\\  ExternalNetCidr: ${deploy_options_array['ext_net_cidr']}' network-environment.yaml
    sed -i '/ExternalAllocationPools/c\\  ExternalAllocationPools: [{'start': '${deploy_options_array['ext_allocation_pool_start']}', 'end': '${deploy_options_array['ext_allocation_pool_end']}'}]' network-environment.yaml
    sed -i '/ExternalInterfaceDefaultRoute/c\\  ExternalInterfaceDefaultRoute: ${deploy_options_array['ext_gateway']}' network-environment.yaml
  fi
fi

openstack undercloud install &> apex-undercloud-install.log
yum downgrade  http://trunk.rdoproject.org/centos7-liberty/f1/48/f148dfacec10e6c0f80a4811944874fcaa92628e_5e110e28/python-tripleoclient-0.0.11-dev93.el7.centos.noarch.rpm
EOI
}

##preping it for deployment and launch the deploy
##params: none
function undercloud_prep_overcloud_deploy {

  if [[ ${#deploy_options_array[@]} -eq 0 || ${deploy_options_array['sdn_controller']} == 'opendaylight' ]]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight.yaml"
  elif [ ${deploy_options_array['sdn_controller']} == 'opendaylight-external' ]; then
    DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/opendaylight-external.yaml"
  elif [ ${deploy_options_array['sdn_controller']} == 'onos' ]; then
    echo -e "${red}ERROR: ONOS is currently unsupported...exiting${reset}"
    exit 1
  elif [ ${deploy_options_array['sdn_controller']} == 'opencontrail' ]; then
    echo -e "${red}ERROR: OpenContrail is currently unsupported...exiting${reset}"
    exit 1
  fi

  # check if HA is enabled
  if [[ "$ha_enabled" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" --control-scale 3 --compute-scale 2"
     DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml"
  fi

  if [[ "$net_isolation_enabled" == "TRUE" ]]; then
     DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml"
     DEPLOY_OPTIONS+=" -e network-environment.yaml"
  fi

  if [[ "$ha_enabled" == "TRUE" ]] || [[ $net_isolation_enabled == "TRUE" ]]; then
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
openstack flavor list | grep baremetal || openstack flavor create --id auto --ram 4096 --disk 39 --vcpus 1 baremetal
openstack flavor list | grep control || openstack flavor create --id auto --ram 4096 --disk 39 --vcpus 1 control
openstack flavor list | grep compute || openstack flavor create --id auto --ram 4096 --disk 39 --vcpus 1 compute
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" baremetal
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="control" control
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="compute" compute
echo "Configuring nameserver on ctlplane network"
neutron subnet-update \$(neutron subnet-list | grep -v id | grep -v \\\\-\\\\- | awk {'print \$2'}) --dns-nameserver 8.8.8.8
echo "Executing overcloud deployment, this should run for an extended period without output."
sleep 60 #wait for Hypervisor stats to check-in to nova
openstack overcloud deploy --templates $DEPLOY_OPTIONS
EOI

}

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   -c|--config : Directory to configuration files. Optional.  Defaults to /var/opt/opnfv/ \n"
  echo -e "   -d|--deploy-settings : Full path to deploy settings yaml file. Optional.  Defaults to null \n"
  echo -e "   -i|--inventory : Full path to inventory yaml file. Required only for baremetal \n"
  echo -e "   -n|--netenv : Full path to network environment file. Optional. Defaults to \$CONFIG/network-environment.yaml \n"
  echo -e "   -p|--ping-site : site to use to verify IP connectivity. Optional. Defaults to 8.8.8.8 \n"
  echo -e "   -r|--resources : Directory to deployment resources. Optional.  Defaults to /var/opt/opnfv/stack \n"
  echo -e "   -v|--virtual : Virtualize overcloud nodes instead of using baremetal. \n"
  echo -e "   --no-ha : disable High Availability deployment scheme, this assumes a single controller and single compute node \n"
  echo -e "   --flat : disable Network Isolation and use a single flat network for the underlay network."
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
        -n|--netenv)
                NETENV=$2
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
        *)
                display_usage
                exit 1
            ;;
    esac
  done

  if [[ ! -z "$NETENV" && "$net_isolation_enabled" == "FALSE" ]]; then
    echo -e "${red}INFO: Single flat network requested. Ignoring any netenv settings!${reset}"
  elif [[ ! -z "$NETENV" && ! -z "$DEPLOY_SETTINGS_FILE" ]]; then
    echo -e "${red}WARN: deploy_settings and netenv specified.  Ignoring netenv settings! deploy_settings will contain \
netenv${reset}"
  fi

  if [[ -n "$virtual" && -n "$INVENTORY_FILE" ]]; then
    echo -e "${red}ERROR: You should not specify an inventory with virtual deployments${reset}"
    exit 1
  fi

  if [[ ! -z "$DEPLOY_SETTINGS_FILE" && ! -f "$DEPLOY_SETTINGS_FILE" ]]; then
    echo -e "${red}ERROR: ${DEPLOY_SETTINGS_FILE} does not exist! Exiting...${reset}"
    exit 1
  fi

  if [[ ! -z "$NETENV" && ! -f "$NETENV" ]]; then
    echo -e "${red}ERROR: ${NETENV} does not exist! Exiting...${reset}"
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
  if ! configure_deps; then
    echo "Dependency Validation Failed, Exiting."
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
}

main "$@"
