#!/usr/bin/env bash
# Common Functions used by  OPNFV Apex
# author: Tim Rozet (trozet@redhat.com)

##converts subnet mask to prefix
##params: subnet mask
function prefix2mask {
  # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}

##find ip of interface
##params: interface name
function find_ip {
  if [[ -z "$1" ]]; then
    return 1
  fi

  python3.4 -B $LIB/python/apex-python-utils.py find_ip -i $1
}

##attach interface to OVS and set the network config correctly
##params: bride to attach to, interface to attach, network type (optional)
##public indicates attaching to a public interface
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
    if_prefix=$(sed -n 's/^PREFIX=\(.*\)$/\1/p' ${if_file})
    if_mask=$(prefix2mask ${if_prefix})
  fi

  if [[ -z "$if_ip" || -z "$if_mask" ]]; then
    echo "ERROR: IPADDR or NETMASK/PREFIX missing for ${interface}"
    return 1
  elif [[ -z "$if_gw" && "$3" == "public_network" ]]; then
    echo "ERROR: GATEWAY missing for ${interface}, which is public"
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

# Update iptables rule for external network reach internet
# for virtual deployments
# params: external_cidr
function configure_undercloud_nat {
  local external_cidr
  if [[ -z "$1" ]]; then
    return 1
  else
    external_cidr=$1
  fi

  ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" <<EOI
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s ${external_cidr} -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth2 -j ACCEPT
iptables -A FORWARD -s ${external_cidr} -m state --state ESTABLISHED,RELATED -j ACCEPT
service iptables save
EOI
}

# Interactive prompt handler
# params: step stage, ex. deploy, undercloud install, etc
function prompt_user {
  while [ 1 ]; do
    echo -n "Would you like to proceed with ${1}? (y/n) "
    read response
    if [ "$response" == 'y' ]; then
      return 0
    elif [ "$response" == 'n' ]; then
      return 1
    else
      continue
    fi
  done
}
