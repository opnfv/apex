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
dnslookup_site="www.google.com"
post_config="TRUE"
debug="FALSE"

ovs_rpm_name=openvswitch-2.5.90-1.el7.centos.x86_64.rpm
ovs_kmod_rpm_name=openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm

declare -i CNT
declare UNDERCLOUD
declare -A deploy_options_array
declare -a performance_options
declare -A NET_MAP

APEX_TMP_DIR=$(python3 -c "import tempfile; print(tempfile.mkdtemp())")
SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
DEPLOY_OPTIONS=""
BASE=${BASE:-'/var/opt/opnfv'}
IMAGES=${IMAGES:-"$BASE/images"}
LIB=${LIB:-"$BASE/lib"}
OPNFV_NETWORK_TYPES="admin tenant external storage api"
ENV_FILE="opnfv-environment.yaml"

VM_CPUS=4
VM_RAM=8
VM_COMPUTES=1

# Netmap used to map networks to OVS bridge names
NET_MAP['admin']="br-admin"
NET_MAP['tenant']="br-tenant"
NET_MAP['external']="br-external"
NET_MAP['storage']="br-storage"
NET_MAP['api']="br-api"
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

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   --deploy-settings | -d : Full path to deploy settings yaml file. Optional.  Defaults to null"
  echo -e "   --inventory | -i : Full path to inventory yaml file. Required only for baremetal"
  echo -e "   --net-settings | -n : Full path to network settings file. Optional."
  echo -e "   --ping-site | -p : site to use to verify IP connectivity. Optional. Defaults to 8.8.8.8"
  echo -e "   --dnslookup-site : site to use to verify DNS resolution. Optional. Defaults to www.google.com"
  echo -e "   --virtual | -v : Virtualize overcloud nodes instead of using baremetal."
  echo -e "   --no-post-config : disable Post Install configuration."
  echo -e "   --debug : enable debug output."
  echo -e "   --interactive : enable interactive deployment mode which requires user to confirm steps of deployment."
  echo -e "   --virtual-cpus : Number of CPUs to use per Overcloud VM in a virtual deployment (defaults to 4)."
  echo -e "   --virtual-computes : Number of Virtual Compute nodes to create and use during deployment (defaults to 1 for noha and 2 for ha)."
  echo -e "   --virtual-default-ram : Amount of default RAM to use per Overcloud VM in GB (defaults to 8)."
  echo -e "   --virtual-compute-ram : Amount of RAM to use per Overcloud Compute VM in GB (defaults to 8). Overrides --virtual-default-ram arg for computes"
  echo -e "   --redeploy-use-existing-undercloud | -r : If given it is assumed that a existing undercloud is available and only overcloud and post deployment is done"
}

##translates the command line parameters into variables
##params: $@ the entire command line is passed
##usage: parse_cmd_line() "$@"
parse_cmdline() {
  echo -e "\n\n${blue}This script is used to deploy the Apex Installer and Provision OPNFV Target System${reset}\n\n"
  echo "Use -h to display help"

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
        -e|--environment-file)
                ENV_FILE=$2
                echo "Base OOO Environment file: $2"
                shift 2
            ;;
        -p|--ping-site)
                ping_site=$2
                echo "Using $2 as the ping site"
                shift 2
            ;;
        --dnslookup-site)
                dnslookup_site=$2
                echo "Using $2 as the dnslookup site"
                shift 2
            ;;
        -v|--virtual)
                virtual="TRUE"
                echo "Executing a Virtual Deployment"
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
        --virtual-default-ram )
                VM_RAM=$2
                echo "Amount of Default RAM per VM set to $VM_RAM"
                shift 2
            ;;
        --virtual-computes )
                VM_COMPUTES=$2
                echo "Virtual Compute nodes set to $VM_COMPUTES"
                shift 2
            ;;
        --virtual-compute-ram )
                VM_COMPUTE_RAM=$2
                echo "Virtual Compute RAM set to $VM_COMPUTE_RAM"
                shift 2
            ;;
        -r | --redeploy-use-existing-undercloud )
                export use_existing_undercloud="TRUE"
                echo "Using existing Undercloud"
                shift 1
            ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done
  sleep 2

  if [[ -z "$NETSETS" ]]; then
    echo -e "${red}ERROR: You must provide a network_settings file with -n.${reset}"
    exit 1
  fi

  # inventory file usage validation
  if [[ -n "$virtual" ]]; then
      if [[ -n "$INVENTORY_FILE" ]]; then
          echo -e "${red}ERROR: You should not specify an inventory file with virtual deployments${reset}"
          exit 1
      else
          INVENTORY_FILE="$APEX_TMP_DIR/inventory-virt.yaml"
      fi
  elif [[ -z "$INVENTORY_FILE" ]]; then
    echo -e "${red}ERROR: You must specify an inventory file for baremetal deployments! Exiting...${reset}"
    exit 1
  elif [[ ! -f "$INVENTORY_FILE" ]]; then
    echo -e "{$red}ERROR: Inventory File: ${INVENTORY_FILE} does not exist! Exiting...${reset}"
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

}

main() {
  parse_cmdline "$@"
  if [ -n "$DEPLOY_SETTINGS_FILE" ]; then
    echo -e "${blue}INFO: Parsing deploy settings file...${reset}"
    parse_deploy_settings
  fi
  echo -e "${blue}INFO: Parsing network settings file...${reset}"
  parse_network_settings
  if ! configure_deps; then
    echo -e "${red}Dependency Validation Failed, Exiting.${reset}"
    exit 1
  fi
  #Correct the time on the server prior to launching any VMs
  if ntpdate $ntp_server; then
    hwclock --systohc
  else
    echo "${blue}WARNING: ntpdate failed to update the time on the server. ${reset}"
  fi
  if [ "$use_existing_undercloud" != "TRUE" ];then
    setup_undercloud_vm
    if [ "$virtual" == "TRUE" ]; then
      setup_virtual_baremetal $VM_CPUS $VM_RAM
    fi
    parse_inventory_file
    configure_undercloud
  else
    get_undercloud_vm_ip
  fi

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
    if ! onos_update_gw_mac ${external_cidr} ${external_gateway}; then
      echo -e "${red}ERROR:ONOS Post Install Configuration Failed, Exiting.${reset}"
      exit 1
    else
      echo -e "${blue}INFO: ONOS Post Install Configuration Complete${reset}"
    fi
  fi
}

main "$@"
