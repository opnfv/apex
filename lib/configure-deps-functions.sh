#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

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

  # try to enabled nested kvm
  if [ "$virtual" == "TRUE" ]; then
    nested_kvm=`cat /sys/module/kvm_intel/parameters/nested`
    if [ "$nested_kvm" != "Y" ]; then
      # try to enable nested kvm
      echo 'options kvm-intel nested=1' > /etc/modprobe.d/kvm_intel.conf
      if rmmod kvm_intel; then
        modprobe kvm_intel
      fi
      nested_kvm=`cat /sys/module/kvm_intel/parameters/nested`
    fi
    if [ "$nested_kvm" != "Y" ]; then
      echo "${red}Cannot enable nested kvm, falling back to qemu for deployment${reset}"
      DEPLOY_OPTIONS+=" --libvirt-type qemu"
    else
      echo "${blue}Nested kvm enabled, deploying with kvm acceleration${reset}"
    fi
  fi

  ##sshkeygen for root
  if [ ! -e ~/.ssh/id_rsa.pub ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
  fi

  echo "${blue}All dependencies installed and running${reset}"
}
