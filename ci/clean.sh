#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

#Clean script to uninstall provisioning server for Apex
#author: Dan Radez (dradez@redhat.com)
#author: Tim Rozet (trozet@redhat.com)

# Use default if no param passed
CONFIG=${1-"/var/opt/opnfv"}

##LIBRARIES
source $CONFIG/lib/common-functions.sh

vm_index=4
ovs_bridges="br-admin br-private br-public br-storage"

# Clean off instack/undercloud VM
for vm in instack undercloud; do
  virsh destroy $vm 2> /dev/null | xargs echo -n
  virsh undefine $vm 2> /dev/null | xargs echo -n
  /usr/bin/touch /var/lib/libvirt/images/${vm}.qcow2
  virsh vol-delete ${vm}.qcow2 --pool default 2> /dev/null | xargs echo -n
  rm -f /var/lib/libvirt/images/${vm}.qcow2 2> /dev/null
done

# Clean off baremetal VMs in case they exist
for i in $(seq 0 $vm_index); do
  virsh destroy baremetal$i 2> /dev/null | xargs echo -n
  virsh undefine baremetal$i 2> /dev/null | xargs echo -n
  /usr/bin/touch /var/lib/libvirt/images/baremetal${i}.qcow2
  virsh vol-delete baremetal${i}.qcow2 --pool default 2> /dev/null | xargs echo -n
  rm -f /var/lib/libvirt/images/baremetal${i}.qcow2 2> /dev/null
done

# Clean off created bridges
for bridge in ${ovs_bridges}; do
  virsh net-destroy ${bridge} 2> /dev/null | xargs echo -n
  virsh net-undefine ${bridge} 2> /dev/null | xargs echo -n
  if detach_interface_from_ovs ${bridge} 2> /dev/null; then
    ovs-vsctl del-br ${bridge} 2> /dev/null
  fi
done

# clean pub keys from root's auth keys
sed -i '/stack@undercloud.localdomain/d' /root/.ssh/authorized_keys
sed -i '/virtual-power-key/d' /root/.ssh/authorized_keys


echo "Cleanup Completed"
