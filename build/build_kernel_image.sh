#!/bin/bash

IMAGE=$1
shift

if [ ! -f $IMAGE.qcow2 ] ; then
  echo "Error: No overcloud image found to create kernel modifications"
  exit 1
fi

LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "bash -x /root/setkernelparam.sh $@" \
    -a $IMAGE.qcow2
