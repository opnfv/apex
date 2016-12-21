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

# Backwards compat for old ENV Vars
# Remove in E Release
if [ -n "$CONFIG" ]; then
    echo -e "${red}WARNING: ENV var CONFIG is Deprecated, please unset CONFIG and export BASE in its place${reset}"
    echo -e "${red}WARNING: CONFIG will be removed in E${reset}"
    BASE=$CONFIG
fi
if [ -n "$RESOURCES" ]; then
    echo -e "${red}WARNING: ENV var RESOURCES is Deprecated, please unset RESOURCES and export IMAGES in its place${reset}"
    echo -e "${red}WARNING: RESOURCES will be removed in E${reset}"
    IMAGES=$RESOURCES
fi

# Use default if no param passed
BASE=${BASE:-'/var/opt/opnfv'}
IMAGES=${IMAGES:-"$BASE/images"}
LIB=${LIB:-"$BASE/lib"}
reset=$(tput sgr0 || echo "")
blue=$(tput setaf 4 || echo "")
red=$(tput setaf 1 || echo "")
green=$(tput setaf 2 || echo "")

##LIBRARIES
for lib in common-functions parse-functions; do
  if ! source $LIB/${lib}.sh; then
    echo "Failed to source $LIB/${lib}.sh"
    exit 1
  fi
done

vm_index=4
ovs_bridges="br-admin br-tenant br-external br-storage"
ovs_bridges+=" br-private br-public" # Legacy names, remove in E river

#OPNFV_NETWORK_TYPES=$(python3 -c 'from apex.common.constants import OPNFV_NETWORK_TYPES; print(" ".join(OPNFV_NETWORK_TYPES))')
OPNFV_NETWORK_TYPES+=" admin tenant external storage api"
OPNFV_NETWORK_TYPES+=" admin_network private_network public_network storage_network api_network" # Legecy names, remove in E river


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
  if ! python3 -B $LIB/python/apex_python_utils.py clean -f ${INVENTORY_FILE}; then
    echo -e "${red}WARN: Unable to shutdown all nodes! Please check /var/log/apex.log${reset}"
  else
    echo -e "${blue}INFO: Node shutdown complete...${reset}"
  fi
fi

# Clean off instack/undercloud VM
for vm in instack undercloud; do
  virsh destroy $vm 2> /dev/null | xargs echo -n
  virsh undefine $vm 2> /dev/null | xargs echo -n
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
sed -i '/virtual-power-key/d' /root/.ssh/authorized_keys


# force storage cleanup
virsh pool-refresh default

# remove temporary files
rm -f /tmp/network-environment.yaml

echo "Cleanup Completed"
