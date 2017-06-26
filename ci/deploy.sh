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

ovs_rpm_name=openvswitch-2.6.1-1.el7.centos.x86_64.rpm
ovs_kmod_rpm_name=openvswitch-kmod-2.6.1-1.el7.centos.x86_64.rpm

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
)
for lib_file in ${lib_files[@]}; do
  if ! source $lib_file; then
    echo -e "${red}ERROR: Failed to source $lib_file${reset}"
    exit 1
  fi
done

main() {
  #Correct the time on the server prior to launching any VMs
  if ntpdate $ntp_server; then
    hwclock --systohc
  else
    echo "${blue}WARNING: ntpdate failed to update the time on the server. ${reset}"
  fi
  setup_undercloud_vm
  if [ "$virtual" == "TRUE" ]; then
    setup_virtual_baremetal $VM_CPUS $VM_RAM
  fi
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
cat > instackenv.json << EOF
$instackenv_output
EOF
EOI
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
}

main "$@"
