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

interactive="FALSE"
ping_site="8.8.8.8"
ntp_server="pool.ntp.org"
net_isolation_enabled="TRUE"
post_config="TRUE"
debug="FALSE"

declare -i CNT
declare UNDERCLOUD
declare -A deploy_options_array
declare -a performance_options
declare -A NET_MAP

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
DEPLOY_OPTIONS=""
CONFIG=${CONFIG:-'/var/opt/opnfv'}
RESOURCES=${RESOURCES:-"$CONFIG/images"}
LIB=${LIB:-"$CONFIG/lib"}
OPNFV_NETWORK_TYPES="admin_network private_network public_network storage_network api_network"

VM_CPUS=4
VM_RAM=8
VM_COMPUTES=2

# Netmap used to map networks to OVS bridge names
NET_MAP['admin_network']="br-admin"
NET_MAP['private_network']="br-private"
NET_MAP['public_network']="br-public"
NET_MAP['storage_network']="br-storage"
NET_MAP['api_network']="br-api"
ext_net_type="interface"
ip_address_family=4

# Libraries
lib_files=(
$LIB/common-functions.sh
$LIB/configure-deps-functions.sh
$LIB/parse-functions.sh
$LIB/virtual-setup-functions.sh
$LIB/undercloud-functions.sh
$LIB/overcloud-deploy-functions.sh
$LIB/post-install-functions.sh
$LIB/utility-functions.sh
$LIB/installer/onos/onos_gw_mac_update.sh
)
for lib_file in ${lib_files[@]}; do
  if ! source $lib_file; then
    echo -e "${red}ERROR: Failed to source $lib_file${reset}"
    exit 1
  fi
done

##FUNCTIONS
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

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   -d|--deploy-settings : Full path to deploy settings yaml file. Optional.  Defaults to null"
  echo -e "   -i|--inventory : Full path to inventory yaml file. Required only for baremetal"
  echo -e "   -n|--net-settings : Full path to network settings file. Optional."
  echo -e "   -p|--ping-site : site to use to verify IP connectivity. Optional. Defaults to 8.8.8.8"
  echo -e "   -v|--virtual : Virtualize overcloud nodes instead of using baremetal."
  echo -e "   --flat : disable Network Isolation and use a single flat network for the underlay network."
  echo -e "   --no-post-config : disable Post Install configuration."
  echo -e "   --debug : enable debug output."
  echo -e "   --interactive : enable interactive deployment mode which requires user to confirm steps of deployment."
  echo -e "   --virtual-cpus : Number of CPUs to use per Overcloud VM in a virtual deployment (defaults to 4)."
  echo -e "   --virtual-ram : Amount of RAM to use per Overcloud VM in GB (defaults to 8)."
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
        -v|--virtual)
                virtual="TRUE"
                echo "Executing a Virtual Deployment"
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
        --virtual-cpus )
                VM_CPUS=$2
                echo "Number of CPUs per VM set to $VM_CPUS"
                shift 2
            ;;
        --virtual-ram )
                VM_RAM=$2
                echo "Amount of RAM per VM set to $VM_RAM"
                shift 2
            ;;
        --virtual-computes )
                VM_COMPUTES=$2
                echo "Virtual Compute nodes set to $VM_COMPUTES"
                shift 2
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
    echo -e "${blue}INFO: Parsing deploy settings file...${reset}"
    parse_deploy_settings
  fi
  setup_undercloud_vm
  if [ "$virtual" == "TRUE" ]; then
    setup_virtual_baremetal $VM_CPUS $VM_RAM
  elif [ -n "$INVENTORY_FILE" ]; then
    parse_inventory_file
  fi
  configure_undercloud
  overcloud_deploy
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
