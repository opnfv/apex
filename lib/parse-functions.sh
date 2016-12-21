#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Parser functions used by OPNFV Apex

##parses network settings yaml into globals
parse_network_settings() {
  local output parse_ext
  parse_ext=''

  if [[ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' || "${deploy_options_array['dataplane']}" == 'fdio' ]]; then
      for val in ${performance_roles[@]}; do
        if [ "$val" == "Compute" ]; then
          parse_ext="${parse_ext} --compute-pre-config "
        elif [ "$val" == "Controller" ]; then
          parse_ext="${parse_ext} --controller-pre-config "
        fi
      done
  fi

  if output=$(python3 -B $LIB/python/apex_python_utils.py parse-net-settings -s $NETSETS -td $APEX_TMP_DIR -e $BASE/network-environment.yaml $parse_ext); then
      echo -e "${blue}${output}${reset}"
      eval "$output"
  else
      echo -e "${red}ERROR: Failed to parse network settings file $NETSETS ${reset}"
      exit 1
  fi

  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    if [[ ! $enabled_network_list =~ "tenant" ]]; then
      echo -e "${red}ERROR: tenant network is not enabled for ovs-dpdk ${reset}"
      exit 1
    fi
  fi
}

##parses deploy settings yaml into globals
parse_deploy_settings() {
  local output
  if output=$(python3 -B $LIB/python/apex_python_utils.py parse-deploy-settings -f $DEPLOY_SETTINGS_FILE); then
      echo -e "${blue}${output}${reset}"
      eval "$output"
  else
      echo -e "${red}ERROR: Failed to parse deploy settings file $DEPLOY_SETTINGS_FILE ${reset}"
      exit 1
  fi

}

##parses baremetal yaml settings into compatible json
##writes the json to undercloud:instackenv.json
##params: none
##usage: parse_inventory_file
parse_inventory_file() {
  local output
  if [ "$virtual" == "TRUE" ]; then inv_virt="--virtual"; fi
  if [[ "$ha_enabled" == "True" ]]; then inv_ha="--ha"; fi
  instackenv_output=$(python3 -B $LIB/python/apex_python_utils.py parse-inventory -f $INVENTORY_FILE $inv_virt $inv_ha)
  #Copy instackenv.json to undercloud
  echo -e "${blue}Parsed instackenv JSON:\n${instackenv_output}${reset}"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
cat > instackenv.json << EOF
$instackenv_output
EOF
EOI
  if output=$(python3 -B $LIB/python/apex_python_utils.py parse-inventory -f $INVENTORY_FILE $inv_virt $inv_ha --export-bash); then
    echo -e "${blue}${output}${reset}"
    eval "$output"
  else
    echo -e "${red}ERROR: Failed to parse inventory bash settings file ${INVENTORY_FILE}${reset}"
    exit 1
  fi

}
