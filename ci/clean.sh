#!/usr/bin/env bash

#Clean script to uninstall provisioning server for Foreman/QuickStack
#author: Dan Radez (dradez@redhat.com)
#
#Uses Vagrant and VirtualBox
#
vm_index=4
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack --remove-all-storage 2> /dev/null || echo -n ''

rm -f /var/lib/libvirt/images/instack.qcow2 2> /dev/null
for i in $(seq 0 $vm_index); do
  virsh destroy baremetalbrbm_brbm1_$i 2> /dev/null || echo -n ''
  virsh undefine baremetalbrbm_brbm1_$i --remove-all-storage 2> /dev/null || echo -n ''
  rm -f /var/lib/libvirt/images/baremetalbrbm_brbm1_${i}.qcow2 2> /dev/null
done
