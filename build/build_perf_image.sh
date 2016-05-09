#!/bin/bash

ROLE=$1
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

# The only perf options we have atm are libvirt pinning and kernel parameters
if [ "$KEY" == "libvirtpin" ]; then
  sudo sed -i "s/#LibvirtCPUPinSet: '1'/LibvirtCPUPinSet: '${VALUE}'" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
else
  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "bash -x /root/setkernelparam.sh $KEY $VALUE" \
    -a $IMAGE
fi

