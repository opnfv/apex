#!/bin/bash

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
    sudo sed -i "s/#LibvirtCPUPinSet: '1'/LibvirtCPUPinSet: '${VALUE}'/" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi
fi

if [ "$CATEGORY" == "kernel" ]; then
  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "bash -x /root/setkernelparam.sh $KEY $VALUE" \
    -a $IMAGE
fi

