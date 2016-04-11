#!/usr/bin/env bash
# Utility Functions used by  OPNFV Apex
# author: Tim Rozet (trozet@redhat.com)

##connects to undercloud
##params: user to login with, command to execute on undercloud (optional)
function undercloud_connect {
  local user=$1

  if [ -z "$1" ]; then
    echo "Missing required argument: user to login as to undercloud"
    return 1
  fi

  if [ -z "$2" ]; then
    ssh ${user}@$(arp -a | grep $(virsh domiflist undercloud | grep default |\
    awk '{print $5}') | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
  else
    ssh -T ${user}@$(arp -a | grep $(virsh domiflist undercloud | grep default \
    | awk '{print $5}') | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+") "$2"
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