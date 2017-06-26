#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

##Create virtual nodes in virsh
##params: vcpus, ramsize
function setup_virtual_baremetal {


    define_vm baremetal${i} network 41 'admin' $vcpus $ramsize
    for n in tenant external storage api; do
      if [[ $enabled_network_list =~ $n ]]; then
        echo -n "$n "
        virsh attach-interface --domain baremetal${i} --type network --source $n --model virtio --config
      fi
    done

    vbmc add baremetal$i --port 623$i
    if service firewalld status > /dev/null; then
        firewall-cmd --permanent --zone=public --add-port=623$i/udp
    fi
    # TODO: add iptables check and commands too
    vbmc start baremetal$i
  done
  if service firewalld status > /dev/null; then
    firewall-cmd --reload
  fi
}

##Create virtual nodes in virsh
##params: name - String: libvirt name for VM
##        bootdev - String: boot device for the VM
##        disksize - Number: size of the disk in GB
##        ovs_bridges: - List: list of ovs bridges
##        vcpus - Number of VCPUs to use (defaults to 4)
##        ramsize - Size of RAM for VM in MB (defaults to 8192)
function define_vm () {
  local vcpus ramsize volume_path direct_boot kernel_args

  if [ -z "$5" ]; then
    vcpus=4
    ramsize=8388608
  elif [ -z "$6" ]; then
    vcpus=$5
    ramsize=8388608
  else
    vcpus=$5
    ramsize=$(($6*1024))
  fi

  # Create the libvirt storage volume
  if virsh vol-list default | grep ${1}.qcow2 2>&1> /dev/null; then
    volume_path=$(virsh vol-path --pool default ${1}.qcow2 || echo "/var/lib/libvirt/images/${1}.qcow2")
    echo "Volume ${1} exists. Deleting Existing Volume $volume_path"
    virsh vol-dumpxml ${1}.qcow2 --pool default > /dev/null || echo '' #ok for this to fail
    touch $volume_path
    virsh vol-delete ${1}.qcow2 --pool default
  fi
  virsh vol-create-as default ${1}.qcow2 ${3}G --format qcow2
  volume_path=$(virsh vol-path --pool default ${1}.qcow2)
  if [ ! -f $volume_path ]; then
      echo "$volume_path Not created successfully... Aborting"
      exit 1
  fi

  # undercloud need to be direct booted.
  # the upstream image no longer includes the kernel and initrd
  if [ "$1" == 'undercloud' ]; then
      direct_boot='--direct-boot overcloud-full'
      kernel_args='--kernel-arg console=ttyS0 --kernel-arg root=/dev/sda'
  fi

  if [ "$(uname -i)" == 'aarch64' ]; then
      diskbus='scsi'
  else
      diskbus='sata'
  fi

  # create the VM
  $LIB/configure-vm --name $1 \
                    --bootdev $2 \
                    --image "$volume_path" \
                    --diskbus $diskbus \
                    --arch $(uname -i) \
                    --cpus $vcpus \
                    --memory $ramsize \
                    --libvirt-nic-driver virtio \
                    $direct_boot \
                    $kernel_args \
                    --baremetal-interface $4
}
