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

##translates yaml into variables
##params: filename, prefix (ex. "config_")
##usage: parse_yaml opnfv_ksgen_settings.yml "config_"
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=%s\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

##parses variable from a string with '='
##and removes global prefix
##params: string, prefix
##usage: parse_setting_var 'deploy_myvar=2' 'deploy_'
parse_setting_var() {
  local mystr=$1
  local prefix=$2
  if echo $mystr | grep -E "^.+\=" > /dev/null; then
    echo $(echo $mystr | grep -Eo "^.+\=" | tr -d '=' |  sed 's/^'"$prefix"'//')
  else
    return 1
  fi
}
##parses value from a string with '='
##params: string
##usage: parse_setting_value
parse_setting_value() {
  local mystr=$1
  echo $(echo $mystr | grep -Eo "\=.*$" | tr -d '=')
}

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

  if output=$(python3 -B $LIB/python/apex_python_utils.py parse-net-settings -s $NETSETS -td $APEX_TMP_DIR -e $CONFIG/network-environment.yaml $parse_ext); then
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

}
