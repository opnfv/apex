#!/bin/bash

# Deploy script to install provisioning server for OPNFV Apex
# author: Dan Radez (dradez@redhat.com)
# author: Tim Rozet (trozet@redhat.com)
#
# Based on RDO Manager http://www.rdoproject.org
#
# Pre-requisties:
#  - Supports 3 or 4 network interface configuration
#  - Target system must be RPM based
#  - Provisioned nodes expected to have following order of network connections (note: not all have to exist, but order is maintained):
#    eth0- admin network
#    eth1- private network (+storage network in 3 NIC config)
#    eth2- public network
#    eth3- storage network
#  - script assumes /24 subnet mask

set -e

##VARIABLES
#reset=`tput sgr0`
#blue=`tput setaf 4`
#red=`tput setaf 1`
#green=`tput setaf 2`

vm_index=4
declare -i CNT
declare UNDERCLOUD

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
DEPLOY_OPTIONS=""
RESOURCES=/var/opt/opnfv/stack
CONFIG=/var/opt/opnfv

##FUNCTIONS
##verify internet connectivity
#params: none
function verify_internet {
  if ping -c 2 8.8.8.8 > /dev/null; then
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
  else
    internet=true
  fi

  # ensure brbm network is configured
  systemctl start openvswitch
  ovs-vsctl list-br | grep brbm > /dev/null || ovs-vsctl add-br brbm
  virsh net-list --all | grep brbm > /dev/null || virsh net-create $CONFIG/brbm-net.xml
  virsh net-list | grep -E "brbm\s+active" > /dev/null || virsh net-start brbm

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

  modprobe kvm
  modprobe kvm_intel

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
      virsh vol-upload --pool default --vol instack.qcow2 --file $CONFIG/stack/instack.qcow2

      sleep 1 # this was to let the copy settle, needed with vol-upload?

  else
      echo "Found Instack VM, using existing VM"
  fi

  # if the VM is not running update the authkeys and start it
  if ! virsh list | grep instack > /dev/null; then
    echo "Injecting ssh key to instack VM"
    virt-customize -c qemu:///system -d instack --upload ~/.ssh/id_rsa.pub:/root/.ssh/authorized_keys \
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

  CNT=10
  echo -en "${blue}\rValidating instack VM connectivity${reset}"
  while ! ping -c 1 $UNDERCLOUD > /dev/null && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 3
      CNT=CNT-1
  done
  CNT=10
  while ! ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "echo ''" 2>&1> /dev/null && [ $CNT -gt 0 ]; do
      echo -n "."
      sleep 3
      CNT=CNT-1
  done

  # extra space to overwrite the previous connectivity output
  echo -e "${blue}\rInstack VM has IP $UNDERCLOUD                                    ${reset}"

  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "if ! ip a s eth1 | grep 192.0.2.1 > /dev/null; then ip a a 192.0.2.1/24 dev eth1; fi"
  # ssh key fix for stack user
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "restorecon -r /home/stack"
}

##Create virtual nodes in virsh
##params: none
function setup_virtual_baremetal {
  for i in $(seq 0 $vm_index); do
    if ! virsh list --all | grep baremetalbrbm_${i} > /dev/null; then
      if [ ! -e $CONFIG/baremetalbrbm_${i}.xml ]; then
        define_virtual_node baremetalbrbm_${i}
      fi
      virsh define $CONFIG/baremetalbrbm_${i}.xml
    else
      echo "Found Baremetal ${i} VM, using existing VM"
    fi
    virsh vol-list default | grep baremetalbrbm_${i} 2>&1> /dev/null || virsh vol-create-as default baremetalbrbm_${i}.qcow2 40G --format qcow2
  done
}

##Copy over the glance images and instack json file
##params: none
function copy_materials {

  echo
  echo "Copying configuration file and disk images to instack"
  scp ${SSH_OPTIONS[@]} $RESOURCES/deploy-ramdisk-ironic.initramfs "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $RESOURCES/deploy-ramdisk-ironic.kernel "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $RESOURCES/ironic-python-agent.initramfs "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $RESOURCES/ironic-python-agent.kernel "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $RESOURCES/ironic-python-agent.vmlinuz "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $RESOURCES/overcloud-full.initrd "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $RESOURCES/overcloud-full.qcow2 "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $RESOURCES/overcloud-full.vmlinuz "stack@$UNDERCLOUD":
  scp ${SSH_OPTIONS[@]} $CONFIG/opendaylight.yaml "stack@$UNDERCLOUD":

  ## WORK AROUND
  # when OpenDaylight lands in upstream RDO manager this can be removed
  # apply the opendaylight patch
  scp ${SSH_OPTIONS[@]} $CONFIG/opendaylight.patch "root@$UNDERCLOUD":
  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "cd /usr/share/openstack-tripleo-heat-templates/; patch -Np1 < /root/opendaylight.patch"
  ## END WORK AROUND

  # ensure stack user on instack machine has an ssh key
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "if [ ! -e ~/.ssh/id_rsa.pub ]; then ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa; fi"

  if [ $virtual == "TRUE" ]; then
      # fix MACs to match new setup
      for i in $(seq 0 $vm_index); do
        pyscript="import json
data = json.load(open('$CONFIG/instackenv-virt.json'))
print data['nodes'][$i]['mac'][0]"

        old_mac=$(python -c "$pyscript")
        new_mac=$(virsh dumpxml baremetalbrbm_$i | grep "mac address" | cut -d = -f2 | grep -Eo "[0-9a-f:]+")
        if [ "$old_mac" != "$new_mac" ]; then
          echo "${blue}Modifying MAC for node from $old_mac to ${new_mac}${reset}"
          sed -i 's/'"$old_mac"'/'"$new_mac"'/' $CONFIG/instackenv-virt.json
        fi
      done

      # upload virt json file
      scp ${SSH_OPTIONS[@]} $CONFIG/instackenv-virt.json "stack@$UNDERCLOUD":instackenv.json

      # allow stack to control power management on the hypervisor via sshkey
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
while read -r line; do
  stack_key=\${stack_key}\\\\\\\\n\${line}
done < <(cat ~/.ssh/id_rsa)
stack_key=\$(echo \$stack_key | sed 's/\\\\\\\\n//')
sed -i 's~INSERT_STACK_USER_PRIV_KEY~'"\$stack_key"'~' instackenv.json
EOI
      DEPLOY_OPTIONS+="--libvirt-type qemu"
  else
      scp ${SSH_OPTIONS[@]} $CONFIG/instackenv.json "stack@$UNDERCLOUD":
  fi


# copy stack's ssh key to this users authorized keys
ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "cat /home/stack/.ssh/id_rsa.pub" >> ~/.ssh/authorized_keys
}

##preping it for deployment and launch the deploy
##params: none
function undercloud_prep_overcloud_deploy {
  # check if HA is enabled
  if [ "$vm_index" -gt 1 ]; then
     DEPLOY_OPTIONS+=" --control-scale 3 --compute-scale 2"
     DEPLOY_OPTIONS+=" -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml"
     DEPLOY_OPTIONS+="  --ntp-server pool.ntp.org"
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
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" baremetal
echo "Configuring nameserver on ctlplane network"
neutron subnet-update \$(neutron subnet-list | grep -v id | grep -v \\\\-\\\\- | awk {'print \$2'}) --dns-nameserver 8.8.8.8
echo "Executing overcloud deployment, this should run for an extended period without output."
sleep 60 #wait for Hypervisor stats to check-in to nova
openstack overcloud deploy --templates $DEPLOY_OPTIONS -e opendaylight.yaml
EOI

}

display_usage() {
  echo -e "\n\n${blue}This script is used to deploy the Apex Installer and Provision OPNFV Target System${reset}\n\n"
  echo -e "\nUsage:\n$0 [arguments] \n"
  echo -e "\n   -c|--config : Full path of settings file to parse. Optional.  Will provide a new base settings file rather than the default.  Example:  --config /opt/myinventory.yml \n"
  echo -e "\n   -r|--resources : Full path of settings file to parse. Optional.  Will provide a new base settings file rather than the default.  Example:  --config /opt/myinventory.yml \n"
  echo -e "\n   -v|--virtual : Virtualize compute nodes instead of using baremetal. \n"
  echo -e "\n   --ping_site : site to use to verify IP connectivity from the VM when -virtual is used.  Format: -ping_site www.blah.com \n"
  echo -e "\n   --floating_ip_count : number of IP address from the public range to be used for floating IP. Default is 20.\n"
}

##translates the command line paramaters into variables
##params: $@ the entire command line is passed
##usage: parse_cmd_line() "$@"
parse_cmdline() {
  echo -e "\n\n${blue}This script is used to deploy the Apex Installer and Provision OPNFV Target System${reset}\n\n"
  echo "Use -h to display help"
  sleep 2

  while [ "$(echo $1 | cut -c1)" = "-" ]
  do
    echo $1
    case "$1" in
        -h|--help)
                display_usage
                exit 0
            ;;
        -c|--config)
                CONFIG=$2
                shift 2
            ;;
        -r|--resources)
                RESOURCES=$2
                shift 2
            ;;
        -v|--virtual)
                virtual="TRUE"
                shift 1
            ;;
        --ping_site)
                ping_site=$2
                shift 2
            ;;
        --floating_ip_count)
                floating_ip_count=$2
                shift 2
            ;;
        -n|--no_ha )
                vm_index=1
                shift 1
           ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done

  if [ -z "$floating_ip_count" ]; then
    floating_ip_count=20
  fi
}

##END FUNCTIONS

main() {
  parse_cmdline "$@"
  configure_deps
  setup_instack_vm
  if [ $virtual == "TRUE" ]; then
    setup_virtual_baremetal
  fi
  copy_materials
  undercloud_prep_overcloud_deploy
}

main "$@"
