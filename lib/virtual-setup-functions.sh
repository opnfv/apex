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
  local vcpus ramsize ram_specified
  if [ -z "$1" ]; then
    vcpus=4
    ramsize=8192
    ram_specified=False
  elif [ -z "$2" ]; then
    vcpus=$1
    ramsize=8192
    ram_specified=False
  else
    vcpus=$1
    ramsize=$(($2*1024))
    ram_specified=True
  fi
  #start by generating the opening json for instackenv.json
  cat > $CONFIG/instackenv-virt.json << EOF
{
  "nodes": [
EOF

  # next create the virtual machines and add their definitions to the file
  if [ "$ha_enabled" == "False" ]; then
      # 1 controller + computes
      # zero based so just pass compute count
      vm_index=$VM_COMPUTES
  else
      # 3 controller + computes
      # zero based so add 2 to compute count
      vm_index=$((2+$VM_COMPUTES))
  fi

  for i in $(seq 0 $vm_index); do
    if [ "$VM_COMPUTES" -gt 0 ]; then
      capability="profile:compute"
      VM_COMPUTES=$((VM_COMPUTES - 1))
    else
      capability="profile:control"
      if [ "$ram_specified" == "False" ]; then
         ramsize=10240
      fi
    fi
    if ! virsh list --all | grep baremetal${i} > /dev/null; then
      define_vm baremetal${i} network 41 'admin_network' $vcpus $ramsize
      for n in private_network public_network storage_network api_network; do
        if [[ $enabled_network_list =~ $n ]]; then
          echo -n "$n "
          virsh attach-interface --domain baremetal${i} --type network --source $n --model virtio --config
        fi
      done
    else
      echo "Found Baremetal ${i} VM, using existing VM"
    fi
    #virsh vol-list default | grep baremetal${i} 2>&1> /dev/null || virsh vol-create-as default baremetal${i}.qcow2 41G --format qcow2
    mac=$(virsh domiflist baremetal${i} | grep admin_network | awk '{ print $5 }')

    cat >> $CONFIG/instackenv-virt.json << EOF
    {
      "pm_addr": "192.168.122.1",
      "pm_user": "root",
      "pm_password": "INSERT_STACK_USER_PRIV_KEY",
      "pm_type": "pxe_ssh",
      "mac": [
        "$mac"
      ],
      "cpu": "$vcpus",
      "memory": "$ramsize",
      "disk": "41",
      "arch": "x86_64",
      "capabilities": "$capability"
    },
EOF
  done

  #truncate the last line to remove the comma behind the bracket
  tail -n 1 $CONFIG/instackenv-virt.json | wc -c | xargs -I {} truncate $CONFIG/instackenv-virt.json -s -{}

  #finally reclose the bracket and close the instackenv.json file
  cat >> $CONFIG/instackenv-virt.json << EOF
    }
  ],
  "arch": "x86_64",
  "host-ip": "192.168.122.1",
  "power_manager": "nova.virt.baremetal.virtual_power_driver.VirtualPowerManager",
  "seed-ip": "",
  "ssh-key": "INSERT_STACK_USER_PRIV_KEY",
  "ssh-user": "root"
}
EOF
  #Overwrite the tripleo-inclubator domain.xml with our own, keeping a backup.
  if [ ! -f /usr/share/tripleo/templates/domain.xml.bak ]; then
    /usr/bin/mv -f /usr/share/tripleo/templates/domain.xml /usr/share/tripleo/templates/domain.xml.bak
  fi

  /usr/bin/cp -f $LIB/installer/domain.xml /usr/share/tripleo/templates/domain.xml
}

##Create virtual nodes in virsh
##params: name - String: libvirt name for VM
##        bootdev - String: boot device for the VM
##        disksize - Number: size of the disk in GB
##        ovs_bridges: - List: list of ovs bridges
##        vcpus - Number of VCPUs to use (defaults to 4)
##        ramsize - Size of RAM for VM in MB (defaults to 8192)
function define_vm () {
  local vcpus ramsize

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

  # create the VM
  /usr/libexec/openstack-tripleo/configure-vm --name $1 \
                                              --bootdev $2 \
                                              --image "$volume_path" \
                                              --diskbus sata \
                                              --arch x86_64 \
                                              --cpus $vcpus \
                                              --memory $ramsize \
                                              --libvirt-nic-driver virtio \
                                              --baremetal-interface $4
}
