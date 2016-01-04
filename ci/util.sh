#!/bin/sh
##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)

display_usage ()
{
cat << EOF
$0 Utilities to interact with an OPNFV Apex Deployment

usage: $0 action target

OPTIONS:
  --debug enable debug
  -h help, prints this help text

Exyample:
$0 ssh undercloud
EOF
}

debug="FALSE"
action=''
target=''

parse_cmdline() {
  while [ "${1:0:1}" = "-" ]
  do
    case "$1" in
        -h|--help)
                display_usage
                exit 0
            ;;
        --debug )
                debug="TRUE"
                echo "Enable debug output"
                shift 1
            ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done

action=$1
target=$2

}

function main() {
  parse_cmdline "$@"
  case "$action" in
      ssh)
          echo -n "Getting the Undercloud IP"
          undercloud=$(arp | grep $(virsh domiflist instack | grep default | awk '{ print $5 }') | awk '{ print $1 }')
          echo ": $undercloud"
          if grep $undercloud ~/.ssh/known_hosts; then
              sed -i "/$undercloud/d" ~/.ssh/known_hosts
          fi
          ssh ${SSH_OPTIONS[@]} stack@$undercloud
          exit 0
          ;;
      *)
          echo "$1 is an unknown utility action"
          exit 1
          ;;
  esac
}

main "$@"
