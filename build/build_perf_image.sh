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
    sudo sed -i 's#^.*ComputeExtraConfigPre.*$#  OS::TripleO::ComputeExtraConfigPre: /usr/share/openstack-tripleo-heat-templates/puppet/extraconfig/pre_deploy/compute/numa.yaml#' network-environment.yaml
  fi
fi

if [ "$CATEGORY" == "kernel" ]; then
  echo "${KEY}=${VALUE}" >> $ROLE-kernel_params.txt
fi

