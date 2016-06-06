#!/bin/bash

##############################################################################
# Copyright (c) 2016 Red Hat Inc.
# Michael Chapman <michapma@redhat.com>, Tim Rozet <trozet@redhat.com>
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

for ROLE in $@; do
  if [ -f $ROLE-overcloud-full.qcow2 ]; then
    RAMDISK=${ROLE}-bm-deploy-ramdisk
    echo "Uploading ${RAMDISK}"
    glance image-create --name ${RAMDISK} --disk-format ari --container-format ari --file ${ROLE}-ironic-python-agent.initramfs --is-public True
    echo "Uploading $ROLE-overcloud-full.qcow2 "
    KERNEL=$(glance image-show overcloud-full | grep 'kernel_id' | cut -d '|' -f 3 | xargs)
    RAMDISK_ID=$(glance image-show ${RAMDISK} | grep id | awk {'print $4'})
    glance image-create --name $ROLE-overcloud-full --disk-format qcow2 --file $ROLE-overcloud-full.qcow2 --container-format bare --property ramdisk_id=$RAMDISK_ID --property kernel_id=$KERNEL --is-public True
  fi

  if [ "$ROLE" == "Controller" ]; then
    sed -i "s/overcloud-full/Controller-overcloud-full/" opnfv-environment.yaml
  fi

  if [ "$ROLE" == "Compute" ]; then
    sudo sed -i "s/NovaImage: .*/NovaImage: Compute-overcloud-full/" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi

  if [ "$ROLE" == "BlockStorage" ]; then
    sudo sed -i "s/BlockStorageImage: .*/BlockStorageImage: BlockStorage-overcloud-full/" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi
done
