#!/usr/bin/env bash

#Clean script to uninstall provisioning server for Foreman/QuickStack
#author: Dan Radez (dradez@redhat.com)
#
#Uses Vagrant and VirtualBox
#
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack --remove-all-storage 2> /dev/null || echo -n ''
virsh destroy baremetalbrbm_0 2> /dev/null || echo -n ''
virsh undefine baremetalbrbm_0 --remove-all-storage 2> /dev/null || echo -n ''
virsh destroy baremetalbrbm_1 2> /dev/null || echo -n ''
virsh undefine baremetalbrbm_1 --remove-all-storage 2> /dev/null || echo -n ''

rm -f /var/lib/libvirt/images/instack.qcow2 2> /dev/null
rm -f /var/lib/libvirt/images/baremetalbrbm_0.qcow2 2> /dev/null
rm -f /var/lib/libvirt/images/baremetalbrbm_1.qcow2 2> /dev/null
