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
  local opnfv_attach_networks ovs_ip ip_range net_cidr tmp_ip af external_network_ipv6
  external_network_ipv6=False
  opnfv_attach_networks="admin"
  if [[ $enabled_network_list =~ "external" ]]; then
    opnfv_attach_networks+=' external'
  fi

  echo -e "${blue}INFO: Post Install Configuration Running...${reset}"

  if [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    echo -e "${blue}INFO: Bringing up br-phy and ovs-agent for dpdk compute nodes...${reset}"
    compute_nodes=$(undercloud_connect stack "source stackrc; nova list | grep compute | wc -l")
    i=0
    while [ "$i" -lt "$compute_nodes" ]; do
      overcloud_connect compute${i} "sudo ifup br-phy; sudo systemctl restart neutron-openvswitch-agent"
      i=$((i + 1))
    done
  fi

  # TODO fix this when HA SDN controllers are supported
  if [ "${deploy_options_array['sdn_controller']}" != 'False' ]; then
    echo -e "${blue}INFO: Finding SDN Controller IP for overcloudrc...${reset}"
    sdn_controller_ip=$(undercloud_connect stack "source stackrc;nova list | grep controller-0 | cut -d '|' -f 7 | grep -Eo [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
    echo -e "${blue}INFO: SDN Controller IP is ${sdn_controller_ip} ${reset}"
    undercloud_connect stack "echo 'export SDN_CONTROLLER_IP=${sdn_controller_ip}' >> /home/stack/overcloudrc"
  fi

  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source overcloudrc
set -o errexit

if [ "${deploy_options_array['dataplane']}" == 'fdio' ] || [ "${deploy_options_array['dataplane']}" == 'ovs_dpdk' ]; then
    for flavor in \$(openstack flavor list -c Name -f value); do
        echo "INFO: Configuring \$flavor to use hugepage"
        nova flavor-key \$flavor set hw:mem_page_size=large
    done
fi

if [ "${deploy_options_array['congress']}" == 'True' ]; then
    ds_configs="--config username=\$OS_USERNAME
                --config tenant_name=\$OS_PROJECT_NAME
                --config password=\$OS_PASSWORD
                --config auth_url=\$OS_AUTH_URL"
    for s in nova neutronv2 cinder glancev2 keystone; do
        ds_extra_configs=""
        if [ "\$s" == "nova" ]; then
            # nova's latest version is 2.38 but congress relies on nova to do
            # floating ip operation instead of neutron. fip support in nova
            # was depricated as of 2.35. Hard coding 2.34 for danube.
            # Carlos.Goncalves working on fixes for upstream congress that
            # should be ready for ocata.
            nova_micro_version="2.34"
            #nova_micro_version=\$(nova version-list | grep CURRENT | awk '{print \$10}')
            ds_extra_configs+="--config api_version=\$nova_micro_version"
        fi
        if openstack congress datasource create \$s "\$s" \$ds_configs \$ds_extra_configs; then
          echo "INFO: Datasource: \$s created"
        else
          echo "WARN: Datasource: \$s could NOT be created"
        fi
    done
    if openstack congress datasource create doctor "doctor"; then
      echo "INFO: Datasource: doctor created"
    else
      echo "WARN: Datsource: doctor could NOT be created"
    fi
fi


EOI

  # we need to restart neutron-server in Gluon deployments to allow the Gluon core
  # plugin to correctly register itself with Neutron
  if [ "${deploy_options_array['gluon']}" == 'True' ]; then
    echo "Restarting neutron-server to finalize Gluon installation"
    overcloud_connect "controller0" "sudo systemctl restart neutron-server"
  fi

  # for virtual, we NAT external network through Undercloud
  # same goes for baremetal if only jumphost has external connectivity
  if [ "$virtual" == "TRUE" ] || ! test_overcloud_connectivity && [ "$external_network_ipv6" != "True" ]; then
    if [[ "$enabled_network_list" =~ "external" ]]; then
      nat_cidr=${external_cidr}
    else
      nat_cidr=${admin_cidr}
    fi
    if ! configure_undercloud_nat ${nat_cidr}; then
      echo -e "${red}ERROR: Unable to NAT undercloud with external net: ${nat_cidr}${reset}"
      exit 1
    else
      echo -e "${blue}INFO: Undercloud VM has been setup to NAT Overcloud external network${reset}"
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

  ### VSPERF ###
  if [[ "${deploy_options_array['vsperf']}" == 'True' ]]; then
    echo "${blue}\nVSPERF enabled, running build_base_machine.sh\n${reset}"
    overcloud_connect "compute0" "sudo sh -c 'cd /var/opt/vsperf/systems/ && ./build_base_machine.sh 2>&1 > /var/log/vsperf.log'"
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

    ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
echo "$node"
sudo openstack-status
EOF
fi
 ssh -T ${SSH_OPTIONS[@]} "heat-admin@\$node" <<EOF
 sudo rm -f /home/heat-admin/messages.log
EOF
done

# Print out the undercloud IP and dashboard URL
source stackrc
echo "Undercloud IP: $UNDERCLOUD, please connect by doing 'opnfv-util undercloud'"
echo "Overcloud dashboard available at http://\$(openstack stack output show overcloud PublicVip -f json | jq -r .output_value)/dashboard"
EOI

if [[ "$ha_enabled" == 'True' ]]; then
  if [ "$debug" == "TRUE" ]; then
    echo "${blue}\nChecking pacemaker service status\n${reset}"
  fi
  overcloud_connect "controller0" "for i in \$(sudo pcs status | grep '^* ' | cut -d ' ' -f 2 | cut -d '_' -f 1 | uniq); do echo \"WARNING: Service: \$i not running\"; done"
fi

if [ "${deploy_options_array['vpn']}" == 'True' ]; then
   # Check zrpcd is started
   overcloud_connect "controller0" "sudo systemctl status zrpcd > /dev/null || echo 'WARNING: zrpcd is not running on controller0'"
fi
}
