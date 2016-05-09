#!/bin/bash

# All overcloud images except the base one, which is already uploaded by the tripleo tool
#for ROLE in $(ls | grep 'overcloud-full' | grep -v 'overcloud-full.qcow2' | cut -d '-' -f 1); do
for ROLE in $@; do
  if [ -f $ROLE-overcloud-full.qcow2 ]; then
    echo "Uploading $ROLE-overcloud-full.qcow2 "
    KERNEL=$(glance image-show overcloud-full | grep 'kernel_id' | cut -d '|' -f 3 | xargs)
    RAMDISK=$(glance image-show overcloud-full | grep 'ramdisk_id' | cut -d '|' -f 3 | xargs)
    glance image-create --name $ROLE-overcloud-full --disk-format qcow2 --file $ROLE-overcloud-full.qcow2 --container-format bare --property ramdisk_id=$RAMDISK --property kernel_id=$KERNEL
  fi

  if [ "$ROLE" == "Controller" ]; then
    sed -i "s/overcloud-full/Controller-overcloud-full" opnfv-environment.yaml
  fi

  if [ "$ROLE" == "Compute" ]; then
    sudo sed -i "s/NovaImage: overcloud-full/Compute-overcloud-full" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi

  if [ "$ROLE" == "BlockStorage" ]; then
    sudo sed -i "s/BlockStorageImage: overcloud-full/BlockStorage-overcloud-full" /usr/share/openstack-tripleo-heat-templates/environments/numa.yaml
  fi
done
