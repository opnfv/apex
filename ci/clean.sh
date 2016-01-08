#!/usr/bin/env bash

#Clean script to uninstall provisioning server for Apex
#author: Dan Radez (dradez@redhat.com)
#
vm_index=4
ovs_bridges="brbm brbm1 brbm2 brbm3"
# Clean off instack VM
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack --remove-all-storage 2> /dev/null || echo -n ''
if ! virsh vol-delete instack.qcow2 --pool default; then
  if [ ! -e /var/lib/libvirt/images/instack.qcow2 ]; then
    /usr/bin/touch /var/lib/libvirt/images/instack.qcow2
    virsh vol-delete instack.qcow2 --pool default
  fi
fi

rm -f /var/lib/libvirt/images/instack.qcow2 2> /dev/null

# Clean off baremetal VMs in case they exist
for i in $(seq 0 $vm_index); do
  virsh destroy baremetalbrbm_brbm1_brbm2_brbm3_$i 2> /dev/null || echo -n ''
  virsh undefine baremetalbrbm_brbm1_brbm2_brbm3_$i --remove-all-storage 2> /dev/null || echo -n ''
  virsh vol-delete baremetalbrbm_brbm1_brbm2_brbm3_${i}.qcow2 --pool default 2> /dev/null
  rm -f /var/lib/libvirt/images/baremetalbrbm_brbm1_brbm2_brbm3_${i}.qcow2 2> /dev/null
done

# Clean off created bridges
for bridge in ${ovs_bridges}; do
  virsh net-destroy ${bridge} 2> /dev/null
  virsh net-undefine ${bridge} 2> /dev/null
  ovs-vsctl del-br ${bridge} 2> /dev/null
done

# clean pub keys from root's auth keys
sed -i '/stack@instack.localdomain/d' /root/.ssh/authorized_keys
sed -i '/virtual-power-key/d' /root/.ssh/authorized_keys


echo "Cleanup Completed"
