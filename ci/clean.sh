#!/usr/bin/env bash

#Clean script to uninstall provisioning server for Apex
#author: Dan Radez (dradez@redhat.com)
#
vm_index=4

# Clean off instack VM
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack --remove-all-storage 2> /dev/null || echo -n ''
virsh vol-delete instack.qcow2 --pool default 2> /dev/null
rm -f /var/lib/libvirt/images/instack.qcow2 2> /dev/null

# Clean off baremetal VMs in case they exist
for i in $(seq 0 $vm_index); do
  virsh destroy baremetalbrbm_brbm1_$i 2> /dev/null || echo -n ''
  virsh undefine baremetalbrbm_brbm1_$i --remove-all-storage 2> /dev/null || echo -n ''
  virsh vol-delete baremetalbrbm_brbm1_${i}.qcow2 --pool default 2> /dev/null
  rm -f /var/lib/libvirt/images/baremetalbrbm_brbm1_${i}.qcow2 2> /dev/null
done

# Clean off brbm bridges
virsh net-destroy brbm 2> /dev/null
virsh net-undefine brbm 2> /dev/null
vs-vsctl del-br brbm 2> /dev/null

virsh net-destroy brbm1 2> /dev/null
virsh net-undefine brbm1 2> /dev/null
vs-vsctl del-br brbm1 2> /dev/null

# clean pub keys from root's auth keys
sed -i '/stack@instack.localdomain/d' /root/.ssh/authorized_keys
sed -i '/virtual-power-key/d' /root/.ssh/authorized_keys


echo "Cleanup Completed"
