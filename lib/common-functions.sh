#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Common Functions used by  OPNFV Apex
# author: Tim Rozet (trozet@redhat.com)

##attach interface to OVS and set the network config correctly
##params: bride to attach to, interface to attach, network type (optional)
##external indicates attaching to a external interface
function attach_interface_to_ovs {
  local bridge interface
  local if_ip if_mask if_gw if_file ovs_file if_prefix
  local if_metric if_dns1 if_dns2

  if [[ -z "$1" || -z "$2" ]]; then
    return 1
  else
    bridge=$1
    interface=$2
  fi

  if ovs-vsctl list-ports ${bridge} | grep ${interface}; then
    return 0
  fi

  if_file=/etc/sysconfig/network-scripts/ifcfg-${interface}
  ovs_file=/etc/sysconfig/network-scripts/ifcfg-${bridge}

  if [ -e "$if_file" ]; then
    if_ip=$(sed -n 's/^IPADDR=\(.*\)$/\1/p' ${if_file})
    if_mask=$(sed -n 's/^NETMASK=\(.*\)$/\1/p' ${if_file})
    if_gw=$(sed -n 's/^GATEWAY=\(.*\)$/\1/p' ${if_file})
    if_metric=$(sed -n 's/^METRIC=\(.*\)$/\1/p' ${if_file})
    if_dns1=$(sed -n 's/^DNS1=\(.*\)$/\1/p' ${if_file})
    if_dns2=$(sed -n 's/^DNS2=\(.*\)$/\1/p' ${if_file})
  else
    echo "ERROR: ifcfg file missing for ${interface}"
    return 1
  fi

  if [ -z "$if_mask" ]; then
    # we can look for PREFIX here, then convert it to NETMASK
    if_prefix=$(sed -n 's/^PREFIX=[^0-9]*\([0-9][0-9]*\)[^0-9]*$/\1/p' ${if_file})
    if_mask=$(prefix2mask ${if_prefix})
  fi

  if [[ -z "$if_ip" || -z "$if_mask" ]]; then
    echo "ERROR: IPADDR or NETMASK/PREFIX missing for ${interface}"
    return 1
  elif [[ -z "$if_gw" && "$3" == "external" ]]; then
    echo "ERROR: GATEWAY missing for ${interface}, which is external"
    return 1
  fi

  # move old config file to .orig
  mv -f ${if_file} ${if_file}.orig
  echo "DEVICE=${interface}
DEVICETYPE=ovs
TYPE=OVSPort
PEERDNS=no
BOOTPROTO=static
NM_CONTROLLED=no
ONBOOT=yes
OVS_BRIDGE=${bridge}
PROMISC=yes" > ${if_file}


  # create bridge cfg
  echo "DEVICE=${bridge}
DEVICETYPE=ovs
IPADDR=${if_ip}
NETMASK=${if_mask}
BOOTPROTO=static
ONBOOT=yes
TYPE=OVSBridge
PROMISC=yes
PEERDNS=no" > ${ovs_file}

  if [ -n "$if_gw" ]; then
    echo "GATEWAY=${if_gw}" >> ${ovs_file}
  fi

  if [ -n "$if_metric" ]; then
    echo "METRIC=${if_metric}" >> ${ovs_file}
  fi

  if [[ -n "$if_dns1" || -n "$if_dns2" ]]; then
    sed -i '/PEERDNS/c\PEERDNS=yes' ${ovs_file}

    if [ -n "$if_dns1" ]; then
      echo "DNS1=${if_dns1}" >> ${ovs_file}
    fi

    if [ -n "$if_dns2" ]; then
      echo "DNS2=${if_dns2}" >> ${ovs_file}
    fi
  fi

  sudo systemctl restart network
}

##detach interface from OVS and set the network config correctly
##params: bridge to detach from
##assumes only 1 real interface attached to OVS
function detach_interface_from_ovs {
  local bridge
  local port_output ports_no_orig
  local net_path
  local if_ip if_mask if_gw if_prefix
  local if_metric if_dns1 if_dns2

  net_path=/etc/sysconfig/network-scripts/
  if [[ -z "$1" ]]; then
    return 1
  else
    bridge=$1
  fi

  # if no interfaces attached then return
  if ! ovs-vsctl list-ports ${bridge} | grep -Ev "vnet[0-9]*"; then
    return 0
  fi

  # look for .orig ifcfg files  to use
  port_output=$(ovs-vsctl list-ports ${bridge} | grep -Ev "vnet[0-9]*")
  while read -r line; do
    if [ -z "$line" ]; then
      continue
    elif [ -e ${net_path}/ifcfg-${line}.orig ]; then
      mv -f ${net_path}/ifcfg-${line}.orig ${net_path}/ifcfg-${line}
    elif [ -e ${net_path}/ifcfg-${bridge} ]; then
      if_ip=$(sed -n 's/^IPADDR=\(.*\)$/\1/p' ${net_path}/ifcfg-${bridge})
      if_mask=$(sed -n 's/^NETMASK=\(.*\)$/\1/p' ${net_path}/ifcfg-${bridge})
      if_gw=$(sed -n 's/^GATEWAY=\(.*\)$/\1/p' ${net_path}/ifcfg-${bridge})
      if_metric=$(sed -n 's/^METRIC=\(.*\)$/\1/p' ${net_path}/ifcfg-${bridge})
      if_dns1=$(sed -n 's/^DNS1=\(.*\)$/\1/p' ${net_path}/ifcfg-${bridge})
      if_dns2=$(sed -n 's/^DNS2=\(.*\)$/\1/p' ${net_path}/ifcfg-${bridge})

      if [ -z "$if_mask" ]; then
        if_prefix=$(sed -n 's/^PREFIX=[^0-9]*\([0-9][0-9]*\)[^0-9]*$/\1/p' ${net_path}/ifcfg-${bridge})
        if_mask=$(prefix2mask ${if_prefix})
      fi

      if [[ -z "$if_ip" || -z "$if_mask" ]]; then
        echo "ERROR: IPADDR or PREFIX/NETMASK missing for ${bridge} and no .orig file for interface ${line}"
        return 1
      fi

      # create if cfg
      echo "DEVICE=${line}
IPADDR=${if_ip}
NETMASK=${if_mask}
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
NM_CONTROLLED=no
PEERDNS=no" > ${net_path}/ifcfg-${line}

      if [ -n "$if_gw" ]; then
        echo "GATEWAY=${if_gw}" >> ${net_path}/ifcfg-${line}
      fi

      if [ -n "$if_metric" ]; then
        echo "METRIC=${if_metric}" >> ${net_path}/ifcfg-${line}
      fi

      if [[ -n "$if_dns1" || -n "$if_dns2" ]]; then
        sed -i '/PEERDNS/c\PEERDNS=yes' ${net_path}/ifcfg-${line}

        if [ -n "$if_dns1" ]; then
          echo "DNS1=${if_dns1}" >> ${net_path}/ifcfg-${line}
        fi

        if [ -n "$if_dns2" ]; then
          echo "DNS2=${if_dns2}" >> ${net_path}/ifcfg-${line}
        fi
      fi
      break
    else
      echo "ERROR: Real interface ${line} attached to bridge, but no interface or ${bridge} ifcfg file exists"
      return 1
    fi

  done <<< "$port_output"

  # modify the bridge ifcfg file
  # to remove IP params
  sudo sed -i 's/IPADDR=.*//' ${net_path}/ifcfg-${bridge}
  sudo sed -i 's/NETMASK=.*//' ${net_path}/ifcfg-${bridge}
  sudo sed -i 's/GATEWAY=.*//' ${net_path}/ifcfg-${bridge}
  sudo sed -i 's/DNS1=.*//' ${net_path}/ifcfg-${bridge}
  sudo sed -i 's/DNS2=.*//' ${net_path}/ifcfg-${bridge}
  sudo sed -i 's/METRIC=.*//' ${net_path}/ifcfg-${bridge}
  sudo sed -i 's/PEERDNS=.*//' ${net_path}/ifcfg-${bridge}

  sudo systemctl restart network
}
