#!/bin/bash

# Update gateway mac to onos for l3 function

# author: Bob zhou
# author: Tim Rozet


# Update gateway mac to onos for l3 function
# params: external CIDR, external gateway
function onos_update_gw_mac {
  local CIDR
  local GW_IP

  if [[ -z "$1" || -z "$2" ]]; then
    return 1
  else
    CIDR=$1
    GW_IP=$2
  fi

  if [ -z "$UNDERCLOUD" ]; then
    #if not found then dnsmasq may be using leasefile-ro
    undercloud_mac=$(virsh domiflist undercloud | grep default | \
                  grep -Eo "[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+")
    UNDERCLOUD=$(/usr/sbin/arp -e | grep ${undercloud_mac} | awk {'print $1'})
  fi
  # get controller ip address
  controller_ip=$(ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source stackrc
openstack server list | grep overcloud-controller-0 | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"
EOI
)

  if [ -z "$controller_ip" ]; then
    echo "ERROR: Failed to find controller_ip for overcloud-controller-0"
    return 1
  fi

  # get gateway mac
  GW_MAC=$(arping ${GW_IP} -c 1 -I br-public | grep -Eo '([0-9a-fA-F]{2})(([/\s:-][0-9a-fA-F]{2}){5})')

  if [ -z "$GW_MAC" ]; then
    echo "ERROR: Failed to find gateway mac for ${GW_IP}"
    return 1
  fi

  # update gateway mac to onos
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
ssh -T ${SSH_OPTIONS[@]} "heat-admin@${controller_ip}" <<EOF
echo "external gateway mac is ${GW_MAC}"
/opt/onos/bin/onos "externalgateway-update -m ${GW_MAC}"
EOF
EOI

}
