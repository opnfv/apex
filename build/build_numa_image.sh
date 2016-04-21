#!/bin/bash

if [ ! -f overcloud-full.qcow2 ] ; then
  echo "Error: No overcloud image found to create numa modifications"
  exit 1
fi

if [ -f overcloud-full-numa.qcow2 ] ; then
  echo "Removing existing numa image"
  rm -f overcloud-full-numa.qcow2
fi
cp overcloud-full.qcow2 overcloud-full-numa.qcow2

if [ "$1" == "" ]; then
  echo "No value provided for isolcpus parameter. NUMA image will be identical to overcloud-full."
  exit 0
fi

LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "bash -x /root/setisolcpus.sh $1" \
    -a overcloud-full-numa.qcow2
