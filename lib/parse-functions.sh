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

  for val in ${performance_roles[@]}; do
    if [ "$val" == "Compute" ]; then
      parse_ext="${parse_ext} --compute-pre-config "
    elif [ "$val" == "Controller" ]; then
      parse_ext="${parse_ext} --controller-pre-config "
    fi
  done

  if output=$(python3.4 -B $LIB/python/apex_python_utils.py parse-net-settings -s $NETSETS $net_isolation_arg -e $CONFIG/network-environment.yaml $parse_ext); then
      echo -e "${blue}${output}${reset}"
      eval "$output"
  else
      echo -e "${red}ERROR: Failed to parse network settings file $NETSETS ${reset}"
      exit 1
  fi
}

##parses deploy settings yaml into globals
parse_deploy_settings() {
  local output
  if output=$(python3.4 -B $LIB/python/apex_python_utils.py parse-deploy-settings -f $DEPLOY_SETTINGS_FILE); then
      echo -e "${blue}${output}${reset}"
      eval "$output"
  else
      echo -e "${red}ERROR: Failed to parse deploy settings file $DEPLOY_SETTINGS_FILE ${reset}"
      exit 1
  fi

  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    if [ "$net_isolation_enabled" == "FALSE" ]; then
      echo -e "${red}ERROR: flat network is not supported with ovs-dpdk ${reset}"
      exit 1
    fi
    if [[ ! $enabled_network_list =~ "private_network" ]]; then
      echo -e "${red}ERROR: tenant network is not enabled for ovs-dpdk ${reset}"
      exit 1
    fi
  fi
}

##parses baremetal yaml settings into compatible json
##writes the json to $CONFIG/instackenv_tmp.json
##params: none
##usage: parse_inventory_file
parse_inventory_file() {
  local inventory=$(parse_yaml $INVENTORY_FILE)
  local node_list
  local node_prefix="node"
  local node_count=0
  local node_total
  local inventory_list

  # detect number of nodes
  for entry in $inventory; do
    if echo $entry | grep -Eo "^nodes_node[0-9]+_" > /dev/null; then
      this_node=$(echo $entry | grep -Eo "^nodes_node[0-9]+_")
      if [[ "$inventory_list" != *"$this_node"* ]]; then
        inventory_list+="$this_node "
      fi
    fi
  done

  inventory_list=$(echo $inventory_list | sed 's/ $//')

  for node in $inventory_list; do
    ((node_count+=1))
  done

  node_total=$node_count

  if [[ "$node_total" -lt 5 && "$ha_enabled" == "True" ]]; then
    echo -e "${red}ERROR: You must provide at least 5 nodes for HA baremetal deployment${reset}"
    exit 1
  elif [[ "$node_total" -lt 2 ]]; then
    echo -e "${red}ERROR: You must provide at least 2 nodes for non-HA baremetal deployment${reset}"
    exit 1
  fi

  eval $(parse_yaml $INVENTORY_FILE) || {
    echo "${red}Failed to parse inventory.yaml. Aborting.${reset}"
    exit 1
  }

  instackenv_output="
{
 \"nodes\" : [

"
  node_count=0
  for node in $inventory_list; do
    ((node_count+=1))
    node_output="
        {
          \"pm_password\": \"$(eval echo \${${node}ipmi_pass})\",
          \"pm_type\": \"$(eval echo \${${node}pm_type})\",
          \"mac\": [
            \"$(eval echo \${${node}mac_address})\"
          ],
          \"cpu\": \"$(eval echo \${${node}cpus})\",
          \"memory\": \"$(eval echo \${${node}memory})\",
          \"disk\": \"$(eval echo \${${node}disk})\",
          \"arch\": \"$(eval echo \${${node}arch})\",
          \"pm_user\": \"$(eval echo \${${node}ipmi_user})\",
          \"pm_addr\": \"$(eval echo \${${node}ipmi_ip})\",
          \"capabilities\": \"$(eval echo \${${node}capabilities})\"
"
    instackenv_output+=${node_output}
    if [ $node_count -lt $node_total ]; then
      instackenv_output+="        },"
    else
      instackenv_output+="        }"
    fi
  done

  instackenv_output+='
  ]
}
'
  #Copy instackenv.json to undercloud for baremetal
  echo -e "{blue}Parsed instackenv JSON:\n${instackenv_output}${reset}"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
cat > instackenv.json << EOF
$instackenv_output
EOF
EOI

}
