#!/bin/bash
##############################################################################
# Copyright (c) 2016 Red Hat Inc.
# Michael Chapman <michapma@redhat.com>
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

ROLE=$1
shift
CATEGORY=$1
shift
KEY=$1
shift
VALUE=$1
shift

IMAGE=$ROLE-overcloud-full.qcow2

# Create image copy for this role
if [ ! -f $IMAGE ] ; then
  cp overcloud-full.qcow2 $IMAGE
fi

if [ "$CATEGORY" == "nova" ]; then
  if [ "$KEY" == "libvirtpin" ]; then
    sudo sed -i "s/#LibvirtCPUPinSet:.*/LibvirtCPUPinSet: '${VALUE}'/" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi
fi

if [ "$CATEGORY" == "kernel" ]; then
  echo "${KEY}=${VALUE}" >> $ROLE-kernel_params.txt
  if [[ "$dataplane" == 'fdio' && "$KEY" == 'hugepages' ]]; then
    # set kernel hugepages params for fdio
    LIBGUESTFS_BACKEND=direct virt-customize --run-command "echo vm.hugetlb_shm_group=0 >> /usr/lib/sysctl.d/00-system.conf" \
                                             --run-command "echo vm.max_map_count=$(printf "%.0f" $(echo 2.2*$VALUE | bc)) >> /usr/lib/sysctl.d/00-system.conf" \
                                             --run-command "echo kernel.shmmax==$((VALUE * 2 * 1024 * 1024)) >> /usr/lib/sysctl.d/00-system.conf" \
                                             -a ${IMAGE}
  fi
fi

if [ "$CATEGORY" == "vpp" ]; then
  if [ "$KEY" == "main-core" ]; then
    sudo sed -i "/${ROLE}VPPMainCore:/c\  ${ROLE}VPPMainCore: '${VALUE}'" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi
  if [ "$KEY" == "corelist-workers" ]; then
    sudo sed -i "/${ROLE}VPPCorelistWorkers:/c\  ${ROLE}VPPCorelistWorkers: '${VALUE}'" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi
  if [ "$KEY" == "uio-driver" ]; then
    sudo sed -i "/${ROLE}UIODriver:/c\  ${ROLE}UIODriver: '${VALUE}'" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi
fi