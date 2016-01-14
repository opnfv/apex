#!/bin/bash

# Update gateway mac to onos for l3 function
# Update instack node pubkey of root to all openstack nodes /root/.ssh/authorized_keys

# author: Bob zhou

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)
UNDERCLOUD=$(grep instack /var/lib/libvirt/dnsmasq/default.leases | awk '{print $3}' | head -n 1)
CIDR="192.168.37.0/24"
GW_IP=192.168.37.1



# Update gateway mac to onos for l3 function
function update_gw_mac {

if [ -z "$UNDERCLOUD" ]; then
    #if not found then dnsmasq may be using leasefile-ro
    instack_mac=$(virsh domiflist instack | grep default | \
                  grep -Eo "[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+")
    UNDERCLOUD=$(/usr/sbin/arp -e | grep ${instack_mac} | awk {'print $1'})
fi
## get controller ip address
controller_ip=$(ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
source stackrc
openstack server list | grep overcloud-controller-0 | grep -o '192\.0\.2\.[0-9]*'
EOI
)

## copy environmet file to controller node
ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
echo "controller node ip is ${controller_ip}"
scp ${SSH_OPTIONS[@]} overcloudrc heat-admin@${controller_ip}:/home/heat-admin/
EOI

## create external network
ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
ssh -T ${SSH_OPTIONS[@]} "heat-admin@${controller_ip}" <<EOF
source overcloudrc
neutron net-create ext-net --shared --router:external=True;
neutron subnet-create ext-net --name ext-subnet $CIDR
EOF
EOI

## get gateway mac
GW_MAC=$(ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
ssh -T ${SSH_OPTIONS[@]} "heat-admin@${controller_ip}" <<EOF
arping ${GW_IP} -c 1 -I br-ex | grep -Eo '([0-9a-fA-F]{2})(([/\s:-][0-9a-fA-F]{2}){5})'
EOF
EOI
)

## update gateway mac to onos
ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" <<EOI
ssh -T ${SSH_OPTIONS[@]} "heat-admin@${controller_ip}" <<EOF
echo "external gateway mac is ${GW_MAC}"
/opt/onos/bin/onos "externalgateway-update -m ${GW_MAC}"
EOF
EOI

}

# Update iptables rule for external network reach internet
function update_iptables_rule {

ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" <<EOI
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.37.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth2 -j ACCEPT
iptables -A FORWARD -s 192.168.37.0/24 -m state --state ESTABLISHED,RELATED -j ACCEPT
service iptables save
EOI
}

main() {
  update_gw_mac
  update_iptables_rule
}

main "$@"
