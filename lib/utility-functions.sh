#!/usr/bin/env bash
# Utility Functions used by  OPNFV Apex
# author: Tim Rozet (trozet@redhat.com)

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)

##connects to undercloud
##params: user to login with, command to execute on undercloud (optional)
function undercloud_connect {
  local user=$1

  if [ -z "$1" ]; then
    echo "Missing required argument: user to login as to undercloud"
    return 1
  fi

  if [ -z "$2" ]; then
    ssh ${SSH_OPTIONS[@]} ${user}@$(get_undercloud_ip)
  else
    ssh ${SSH_OPTIONS[@]} -T ${user}@$(get_undercloud_ip) "$2"
  fi
}

##outputs the Undercloud's IP address
##params: none
function get_undercloud_ip {
  echo $(arp -a | grep $(virsh domiflist undercloud | grep default |\
    awk '{print $5}') | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
}

##connects to overcloud nodes
##params: node to login to, command to execute on overcloud (optional)
function overcloud_connect {
  local node
  local node_output
  local node_ip

  if [ -z "$1" ]; then
    echo "Missing required argument: overcloud node to login to"
    return 1
  elif ! echo "$1" | grep -E "(controller|compute)[0-9]+" > /dev/null; then
    echo "Invalid argument: overcloud node to login to must be in the format: \
controller<number> or compute<number>"
    return 1
  fi

  node_output=$(undercloud_connect "stack" "source stackrc; nova list")
  node=$(echo "$1" | sed -E 's/([a-zA-Z]+)([0-9]+)/\1-\2/')

  node_ip=$(echo "$node_output" | grep "$node" | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")

  if [ "$node_ip" == "" ]; then
    echo -e "Unable to find IP for ${node} in \n${node_output}"
    return 1
  fi

  if [ -z "$2" ]; then
    ssh ${SSH_OPTIONS[@]} heat-admin@${node_ip}
  else
    ssh ${SSH_OPTIONS[@]} -T heat-admin@${node_ip} "$2"
  fi
}

##outputs heat stack deployment failures
##params: none
function debug_stack {
  local failure_output
  local phys_id
  declare -a resource_arr
  declare -a phys_id_arr

  source ~/stackrc

  IFS=$'\n'
  for resource in $(heat resource-list -n 5 overcloud | grep FAILED); do
    unset IFS
    resource_arr=(${resource//|/ })
    phys_id=$(heat resource-show ${resource_arr[-1]} ${resource_arr[0]} | grep physical_resource_id 2> /dev/null)
    if [ -n "$phys_id" ]; then
      phys_id_arr=(${phys_id//|/ })
      failure_output+="******************************************************"
      failure_output+="\n${resource}:\n\n$(heat deployment-show ${phys_id_arr[-1]} 2> /dev/null)"
      failure_output+="\n******************************************************"
    fi
    unset phys_id
  done

  echo -e $failure_output
}
