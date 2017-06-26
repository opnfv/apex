#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

#Clean script to uninstall provisioning server for Apex
#author: Dan Radez (dradez@redhat.com)
#author: Tim Rozet (trozet@redhat.com)

reset=$(tput sgr0 || echo "")
blue=$(tput setaf 4 || echo "")
red=$(tput setaf 1 || echo "")
green=$(tput setaf 2 || echo "")

vm_index=4
ovs_bridges="br-admin br-tenant br-external br-storage"
ovs_bridges+=" br-private br-public" # Legacy names, remove in E river

#OPNFV_NETWORK_TYPES=$(python3 -c 'from apex.common.constants import OPNFV_NETWORK_TYPES; print(" ".join(OPNFV_NETWORK_TYPES))')
OPNFV_NETWORK_TYPES+=" admin tenant external storage api"
OPNFV_NETWORK_TYPES+=" admin_network private_network public_network storage_network api_network" # Legecy names, remove in E river

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

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   -i|--inventory : Full path to inventory yaml file. Required only for baremetal node clean"
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
        -i|--inventory)
                INVENTORY_FILE=$2
                shift 2
            ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done

  if [[ ! -z "$INVENTORY_FILE" && ! -f "$INVENTORY_FILE" ]]; then
    echo -e "{$red}ERROR: Inventory File: ${INVENTORY_FILE} does not exist! Exiting...${reset}"
    exit 1
  fi
}

parse_cmdline "$@"

if [ -n "$INVENTORY_FILE" ]; then
  echo -e "${blue}INFO: Parsing inventory file...${reset}"
  # hack for now (until we switch fully over to clean.py) to tell if
  # we should install apex from python or if rpm is being used
  if ! rpm -q opnfv-apex-common > /dev/null; then
    pushd ../ && python3 setup.py install > /dev/null
    popd
  fi
  if ! python3 -m apex.clean -f ${INVENTORY_FILE}; then
    echo -e "${red}WARN: Unable to shutdown all nodes! Please check /var/log/apex.log${reset}"
  else
    echo -e "${blue}INFO: Node shutdown complete...${reset}"
  fi
fi

# Clean off instack/undercloud VM
for vm in instack undercloud; do
  virsh destroy $vm 2> /dev/null | xargs echo -n
  virsh undefine --nvram $vm 2> /dev/null | xargs echo -n
  /usr/bin/touch /var/lib/libvirt/images/${vm}.qcow2
  virsh vol-delete ${vm}.qcow2 --pool default 2> /dev/null | xargs echo -n
  rm -f /var/lib/libvirt/images/${vm}.qcow2 2> /dev/null
done

# Clean off baremetal VMs in case they exist
for i in $(seq 0 $vm_index); do
  virsh destroy baremetal$i 2> /dev/null | xargs echo -n
  virsh undefine baremetal$i 2> /dev/null | xargs echo -n
  /usr/bin/touch /var/lib/libvirt/images/baremetal${i}.qcow2
  virsh vol-delete baremetal${i}.qcow2 --pool default 2> /dev/null | xargs echo -n
  rm -f /var/lib/libvirt/images/baremetal${i}.qcow2 2> /dev/null
  if [ -e /root/.vbmc/baremetal$i ]; then vbmc delete baremetal$i; fi
done

for network in ${OPNFV_NETWORK_TYPES}; do
  virsh net-destroy ${network} 2> /dev/null
  virsh net-undefine ${network} 2> /dev/null
done

# Clean off created bridges
for bridge in ${ovs_bridges}; do
  if detach_interface_from_ovs ${bridge} 2> /dev/null; then
    ovs-vsctl del-br ${bridge} 2> /dev/null
    rm -f /etc/sysconfig/network-scripts/ifcfg-${bridge}
  fi
done

# clean pub keys from root's auth keys
sed -i '/stack@undercloud.localdomain/d' /root/.ssh/authorized_keys


# force storage cleanup
virsh pool-refresh default

# remove temporary files
rm -f /tmp/network-environment.yaml

echo "Cleanup Completed"
