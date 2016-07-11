#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

##Post configuration after install
##params: none
function configure_post_install {
  local opnfv_attach_networks ovs_ip ip_range net_cidr tmp_ip
  opnfv_attach_networks="admin_network public_network"

  echo -e "${blue}INFO: Post Install Configuration Running...${reset}"

  echo -e "${blue}INFO: Configuring ssh for root to overcloud nodes...${reset}"
  # copy host key to instack
  scp ${SSH_OPTIONS[@]} /root/.ssh/id_rsa.pub "stack@$UNDERCLOUD":jumphost_id_rsa.pub

  # add host key to overcloud nodes authorized keys
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
source stackrc
nodes=\$(nova list | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
for node in \$nodes; do
cat ~/jumphost_id_rsa.pub | ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" 'cat >> ~/.ssh/authorized_keys'
done
EOI

  echo -e "${blue}INFO: Checking if OVS bridges have IP addresses...${reset}"
  for network in ${opnfv_attach_networks}; do
    ovs_ip=$(find_ip ${NET_MAP[$network]})
    tmp_ip=''
    if [ -n "$ovs_ip" ]; then
      echo -e "${blue}INFO: OVS Bridge ${NET_MAP[$network]} has IP address ${ovs_ip}${reset}"
    else
      echo -e "${blue}INFO: OVS Bridge ${NET_MAP[$network]} missing IP, will configure${reset}"
      # use last IP of allocation pool
      eval "ip_range=\${${network}_usable_ip_range}"
      ovs_ip=${ip_range##*,}
      eval "net_cidr=\${${network}_cidr}"
      sudo ip addr add ${ovs_ip}/${net_cidr##*/} dev ${NET_MAP[$network]}
      sudo ip link set up ${NET_MAP[$network]}
      tmp_ip=$(find_ip ${NET_MAP[$network]})
      if [ -n "$tmp_ip" ]; then
        echo -e "${blue}INFO: OVS Bridge ${NET_MAP[$network]} IP set: ${tmp_ip}${reset}"
        continue
      else
        echo -e "${red}ERROR: Unable to set OVS Bridge ${NET_MAP[$network]} with IP: ${ovs_ip}${reset}"
        return 1
      fi
    fi
  done

  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    echo -e "${blue}INFO: Bringing up br-phy and ovs-agent for dpdk compute nodes...${reset}"
    compute_nodes=$(undercloud_connect stack "source stackrc; nova list | grep compute | wc -l")
    i=0
    while [ "$i" -lt "$compute_nodes" ]; do
      overcloud_connect compute${i} "sudo ifup br-phy; sudo systemctl restart neutron-openvswitch-agent"
      i=$((i + 1))
    done
  fi

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source overcloudrc
set -o errexit
echo "Configuring Neutron external network"
neutron net-create external --router:external=True --tenant-id \$(openstack project show service | grep id | awk '{ print \$4 }')
neutron subnet-create --name external-net --tenant-id \$(openstack project show service | grep id | awk '{ print \$4 }') --disable-dhcp external --gateway ${public_network_gateway} --allocation-pool start=${public_network_floating_ip_range%%,*},end=${public_network_floating_ip_range##*,} ${public_network_cidr}

echo "Removing sahara endpoint and service"
sahara_service_id=\$(openstack service list | grep sahara | cut -d ' ' -f 2)
sahara_endpoint_id=\$(openstack endpoint list | grep sahara | cut -d ' ' -f 2)
openstack endpoint delete \$sahara_endpoint_id
openstack service delete \$sahara_service_id

echo "Removing swift endpoint and service"
swift_service_id=\$(openstack service list | grep swift | cut -d ' ' -f 2)
swift_endpoint_id=\$(openstack endpoint list | grep swift | cut -d ' ' -f 2)
openstack endpoint delete \$swift_endpoint_id
openstack service delete \$swift_service_id

if [ "${deploy_options_array['congress']}" == 'True' ]; then
    for s in nova neutronv2 ceilometer cinder glancev2 keystone; do
        openstack congress datasource create \$s "\$s" \\
            --config username=\$OS_USERNAME \\
            --config tenant_name=\$OS_TENANT_NAME \\
            --config password=\$OS_PASSWORD \\
            --config auth_url=\$OS_AUTH_URL
    done
fi
EOI

  # for virtual, we NAT public network through Undercloud
  if [ "$virtual" == "TRUE" ]; then
    if ! configure_undercloud_nat ${public_network_cidr}; then
      echo -e "${red}ERROR: Unable to NAT undercloud with external net: ${public_network_cidr}${reset}"
      exit 1
    else
      echo -e "${blue}INFO: Undercloud VM has been setup to NAT Overcloud public network${reset}"
    fi
  fi

  # for sfc deployments we need the vxlan workaround
  if [ "${deploy_options_array['sfc']}" == 'True' ]; then
      ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source stackrc
set -o errexit
for node in \$(nova list | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"); do
ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
sudo ifconfig br-int up
sudo ip route add 123.123.123.0/24 dev br-int
EOF
done
EOI
  fi

  # Collect deployment logs
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
mkdir -p ~/deploy_logs
rm -rf deploy_logs/*
source stackrc
set -o errexit
for node in \$(nova list | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"); do
 ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
 sudo cp /var/log/messages /home/heat-admin/messages.log
 sudo chown heat-admin /home/heat-admin/messages.log
EOF
scp ${SSH_OPTIONS[@]} heat-admin@\$node:/home/heat-admin/messages.log ~/deploy_logs/\$node.messages.log
if [ "$debug" == "TRUE" ]; then
    nova list --ip \$node
    echo "---------------------------"
    echo "-----/var/log/messages-----"
    echo "---------------------------"
    cat ~/deploy_logs/\$node.messages.log
    echo "---------------------------"
    echo "----------END LOG----------"
    echo "---------------------------"
fi
 ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
 sudo rm -f /home/heat-admin/messages.log
EOF
done

# Print out the undercloud IP and dashboard URL
source stackrc
echo "Undercloud IP: $UNDERCLOUD, please connect by doing 'opnfv-util undercloud'"
echo "Overcloud dashboard available at http://\$(heat output-show overcloud PublicVip | sed 's/"//g')/dashboard"
EOI
}
