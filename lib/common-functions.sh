#!/usr/bin/env bash
# Common Functions used by  OPNFV Apex
# author: Tim Rozet (trozet@redhat.com)

#python ip_gen command
ip_gen="python3 -m ip_utils generate_ip_range"

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
  ip addr show $1 | grep -Eo '^\s+inet\s+[\.0-9]+' | awk '{print $2}'
}

##finds subnet of ip and netmask
##params: ip, netmask
function find_subnet {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  IFS=. read -r m1 m2 m3 m4 <<< "$2"
  printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
}

##verify subnet has at least n IPs
##params: subnet mask, n IPs
function verify_subnet_size {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  num_ips_required=$2

  ##this function assumes you would never need more than 254
  ##we check here to make sure
  if [ "$num_ips_required" -ge 254 ]; then
    echo -e "\n\n${red}ERROR: allocating more than 254 IPs is unsupported...Exiting${reset}\n\n"
    return 1
  fi

  ##we just return if 3rd octet is not 255
  ##because we know the subnet is big enough
  if [ "$i3" -ne 255 ]; then
    return 0
  elif [ $((254-$i4)) -ge "$num_ips_required" ]; then
    return 0
  else
    echo -e "\n\n${red}ERROR: Subnet is too small${reset}\n\n"
    return 1
  fi
}

##finds last usable ip (broadcast minus 1) of a subnet from an IP and netmask
## Warning: This function only works for IPv4 at the moment.
##params: ip, netmask
function find_last_ip_subnet {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  IFS=. read -r m1 m2 m3 m4 <<< "$2"
  IFS=. read -r s1 s2 s3 s4 <<< "$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$((i4 & m4))"
  printf "%d.%d.%d.%d\n" "$((255 - $m1 + $s1))" "$((255 - $m2 + $s2))" "$((255 - $m3 + $s3))" "$((255 - $m4 + $s4 - 1))"
}

##increments subnet by a value
##params: ip, value
##assumes low value
function increment_subnet {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  printf "%d.%d.%d.%d\n" "$i1" "$i2" "$i3" "$((i4 | $2))"
}

##finds netmask of interface
##params: interface
##returns long format 255.255.x.x
function find_netmask {
  ifconfig $1 | grep -Eo 'netmask\s+[\.0-9]+' | awk '{print $2}'
}

##finds short netmask of interface
##params: interface
##returns short format, ex: /21
function find_short_netmask {
  echo "/$(ip addr show $1 | grep -Eo '^\s+inet\s+[\/\.0-9]+' | awk '{print $2}' | cut -d / -f2)"
}

##increments next IP
##params: ip
##assumes a /24 subnet
function next_ip {
  baseaddr="$(echo $1 | cut -d. -f1-3)"
  lsv="$(echo $1 | cut -d. -f4)"
  if [ "$lsv" -ge 254 ]; then
    return 1
  fi
  ((lsv++))
  echo $baseaddr.$lsv
}

##subtracts a value from an IP address
##params: last ip, ip_count
##assumes ip_count is less than the last octect of the address
subtract_ip() {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  ip_count=$2
  if [ $i4 -lt $ip_count ]; then
    echo -e "\n\n${red}ERROR: Can't subtract $ip_count from IP address $1  Exiting${reset}\n\n"
    exit 1
  fi
  printf "%d.%d.%d.%d\n" "$i1" "$i2" "$i3" "$((i4 - $ip_count ))"
}

##check if IP is in use
##params: ip
##ping ip to get arp entry, then check arp
function is_ip_used {
  ping -c 5 $1 > /dev/null 2>&1
  arp -n | grep "$1 " | grep -iv incomplete > /dev/null 2>&1
}

##find next usable IP
##params: ip
function next_usable_ip {
  new_ip=$(next_ip $1)
  while [ "$new_ip" ]; do
    if ! is_ip_used $new_ip; then
      echo $new_ip
      return 0
    fi
    new_ip=$(next_ip $new_ip)
  done
  return 1
}

##increment ip by value
##params: ip, amount to increment by
##increment_ip $next_private_ip 10
function increment_ip {
  baseaddr="$(echo $1 | cut -d. -f1-3)"
  lsv="$(echo $1 | cut -d. -f4)"
  incrval=$2
  lsv=$((lsv+incrval))
  if [ "$lsv" -ge 254 ]; then
    return 1
  fi
  echo $baseaddr.$lsv
}

##finds gateway on system
##params: interface to validate gateway on (optional)
##find_gateway em1
function find_gateway {
  local gw gw_interface
  if [ -z "$1"  ]; then
    return 1
  fi
  gw=$(ip route | grep default | awk '{print $3}')
  gw_interface=$(ip route get $gw | awk '{print $3}')
  if [ -n "$1" ]; then
    if [ "$gw_interface" == "$1" ]; then
      echo ${gw}
    fi
  fi
}

##finds subnet in CIDR notation for interface
##params: interface to find CIDR
function find_cidr {
  local cidr network ip netmask short_mask
  if [ -z "$1"  ]; then
    return 1
  fi
  ip=$(find_ip $1)
  netmask=$(find_netmask $1)
  if [[ -z "$ip" || -z "$netmask" ]]; then
    return 1
  fi
  network=$(find_subnet ${ip} ${netamsk})
  short_mask=$(find_short_netmask $1)
  if [[ -z "$network" || -z "$short_mask" ]]; then
    return 1
  fi
  cidr="${subnet}'\'${short_mask}"
  echo ${cidr}
}

##finds block of usable IP addresses for an interface
##simply returns at the moment the correct format
##after first 20 IPs, and leave 20 IPs at end of subnet (for floating ips, etc)
##params: interface to find IP
function find_usable_ip_range {
  local interface_ip subnet_mask first_block_ip last_block_ip
  if [ -z "$1"  ]; then
    return 1
  fi
  interface_ip=$(find_ip $1)
  subnet_mask=$(find_netmask $1)
  if [[ -z "$interface_ip" || -z "$subnet_mask" ]]; then
    return 1
  fi
  interface_ip=$(increment_ip ${interface_ip} 20)
  first_block_ip=$(next_usable_ip ${interface_ip})
  if [ -z "$first_block_ip" ]; then
    return 1
  fi
  last_block_ip=$(find_last_ip_subnet ${interface_ip} ${subnet_mask})
  if [ -z "$last_block_ip" ]; then
    return 1
  else
    last_block_ip=$(subtract_ip ${last_block_ip} 21)
    echo "${first_block_ip},${last_block_ip}"
  fi

}

##generates usable IP range in correct format based on CIDR
##assumes the first 20 IPs are used (by undercloud or otherwise)
##params: cidr
function generate_usable_ip_range {
  if [ -z "$1" ]; then
    return 1
  fi
  echo $($ip_gen $1 21 -23)
}


##find the undercloud IP address
##finds first usable IP on subnet
##params: interface
function find_provisioner_ip {
  local interface_ip
  if [ -z "$1"  ]; then
    return 1
  fi
  interface_ip=$(find_ip $1)
  if [ -z "$interface_ip" ]; then
    return 1
  fi
  echo $(increment_ip ${interface_ip} 1)
}

##generates undercloud IP address based on CIDR
##params: cidr
function generate_provisioner_ip {
  if [ -z "$1" ]; then
    return 1
  fi
  echo $($ip_gen $1 1 1)
}


##finds the dhcp range available via interface
##uses first 8 IPs, after 2nd IP
##params: interface
function find_dhcp_range {
  local dhcp_range_start dhcp_range_end interface_ip
  if [ -z "$1"  ]; then
    return 1
  fi
  interface_ip=$(find_ip $1)
  if [ -z "$interface_ip" ]; then
    return 1
  fi
  dhcp_range_start=$(increment_ip ${interface_ip} 2)
  dhcp_range_end=$(increment_ip ${dhcp_range_start} 8)
  echo "${dhcp_range_start},${dhcp_range_end}"
}

##generates the dhcp range available via CIDR
##uses first 8 IPs, after 1st IP
##params: cidr
function generate_dhcp_range {
  if [ -z "$1" ]; then
    return 1
  fi
  echo $($ip_gen $1 2 10)
}

##finds the introspection range available via interface
##uses 8 IPs, after the first 10 IPs
##params: interface
function find_introspection_range {
  local inspect_range_start inspect_range_end interface_ip
  if [ -z "$1"  ]; then
    return 1
  fi
  interface_ip=$(find_ip $1)
  if [ -z "$interface_ip" ]; then
    return 1
  fi
  inspect_range_start=$(increment_ip ${interface_ip} 10)
  inspect_range_end=$(increment_ip ${inspect_range_start} 8)
  echo "${inspect_range_start},${inspect_range_end}"
}

##generate the introspection range available via CIDR
##uses 8 IPs, after the first 10 IPs
##params: cidr
function generate_introspection_range {
  if [ -z "$1" ]; then
    return 1
  fi
  echo $($ip_gen $1 11 19)
}

##finds the floating ip range available via interface
##uses last 20 IPs of a subnet, minus last IP
##params: interface
function find_floating_ip_range {
  local float_range_start float_range_end interface_ip subnet_mask
  if [ -z "$1"  ]; then
    return 1
  fi
  interface_ip=$(find_ip $1)
  subnet_mask=$(find_netmask $1)
  if [[ -z "$interface_ip" || -z "$subnet_mask" ]]; then
    return 1
  fi
  float_range_end=$(find_last_ip_subnet ${interface_ip} ${subnet_mask})
  float_range_end=$(subtract_ip ${float_range_end} 1)
  float_range_start=$(subtract_ip ${float_range_end} 19)
  echo "${float_range_start},${float_range_end}"
}

##generate the floating range available via CIDR
##uses last 20 IPs of subnet, minus last IP
##params: cidr
function generate_floating_ip_range {
  if [ -z "$1" ]; then
    return 1
  fi
  echo $($ip_gen $1 -22 -3)
}

##attach interface to OVS and set the network config correctly
##params: bride to attach to, interface to attach, network type (optional)
##public indicates attaching to a public interface
function attach_interface_to_ovs {
  local bridge interface
  local if_ip if_mask if_gw if_file ovs_file if_prefix

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

  if [ -z ${if_gw} ]; then
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

  else
    echo "DEVICE=${bridge}
DEVICETYPE=ovs
IPADDR=${if_ip}
NETMASK=${if_mask}
BOOTPROTO=static
ONBOOT=yes
TYPE=OVSBridge
PROMISC=yes
GATEWAY=${if_gw}
PEERDNS=no" > ${ovs_file}
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
      if_ip=$(sed -n 's/^IPADDR=\(.*\)$/\1/p' ${if_file})
      if_mask=$(sed -n 's/^NETMASK=\(.*\)$/\1/p' ${if_file})
      if_gw=$(sed -n 's/^GATEWAY=\(.*\)$/\1/p' ${if_file})

      if [ -z "$if_mask" ]; then
        if_prefix=$(sed -n 's/^PREFIX=\(.*\)$/\1/p' ${if_file})
        if_mask=$(prefix2mask ${if_prefix})
      fi

      if [[ -z "$if_ip" || -z "$if_mask" ]]; then
        echo "ERROR: IPADDR or PREFIX/NETMASK missing for ${bridge} and no .orig file for interface ${line}"
        return 1
      fi

      if [ -z ${if_gw} ]; then
        # create if cfg
        echo "DEVICE=${line}
IPADDR=${if_ip}
NETMASK=${if_mask}
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
NM_CONTROLLED=no
PEERDNS=no" > ${net_path}/ifcfg-${line}
      else
        echo "DEVICE=${line}
IPADDR=${if_ip}
NETMASK=${if_mask}
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
NM_CONTROLLED=no
GATEWAY=${if_gw}
PEERDNS=no" > ${net_path}/ifcfg-${line}
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
