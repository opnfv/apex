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
  local vcpus ramsize held_ramsize
  if [ -z "$1" ]; then
    vcpus=4
    ramsize=8192
  elif [ -z "$2" ]; then
    vcpus=$1
    ramsize=8192
  else
    vcpus=$1
    ramsize=$(($2*1024))
  fi
  #start by generating the opening yaml for the inventory-virt.yaml file
  cat > $APEX_TMP_DIR/inventory-virt.yaml << EOF
nodes:
EOF

  # next create the virtual machines and add their definitions to the file
  if [ "$ha_enabled" == "False" ]; then
      controller_index=0
  else
      controller_index=2
      # 3 controller + computes
      # zero based so add 2 to compute count
      if [ $VM_COMPUTES -lt 2 ]; then
          VM_COMPUTES=2
      fi
  fi

  # tmp var to hold ramsize in case modified during detection
  held_ramsize=${ramsize}
  for i in $(seq 0 $(($controller_index+$VM_COMPUTES))); do
    ramsize=${held_ramsize}
    if [ $i -gt $controller_index ]; then
      capability="profile:compute"
      if [ -n "$VM_COMPUTE_RAM" ]; then
        ramsize=$((${VM_COMPUTE_RAM}*1024))
      fi
    else
      capability="profile:control"
      if [[ "${deploy_options_array['sdn_controller']}" == 'opendaylight' && "$ramsize" -lt 10240 ]]; then
         echo "WARN: RAM per controller too low.  OpenDaylight specified in HA deployment requires at least 10GB"
         echo "INFO: Increasing RAM per controller to 10GB"
         ramsize=10240
      fi
    fi
    if ! virsh list --all | grep baremetal${i} > /dev/null; then
      define_vm baremetal${i} network 41 'admin' $vcpus $ramsize
      for n in tenant external storage api; do
        if [[ $enabled_network_list =~ $n ]]; then
          echo -n "$n "
          virsh attach-interface --domain baremetal${i} --type network --source $n --model virtio --config
        fi
      done
    else
      echo "Found baremetal${i} VM, using existing VM"
    fi
    #virsh vol-list default | grep baremetal${i} 2>&1> /dev/null || virsh vol-create-as default baremetal${i}.qcow2 41G --format qcow2
    mac=$(virsh domiflist baremetal${i} | grep admin | awk '{ print $5 }')

    cat >> $APEX_TMP_DIR/inventory-virt.yaml << EOF
  node${i}:
    mac_address: "$mac"
    ipmi_ip: 192.168.122.1
    ipmi_user: root
    ipmi_pass: "INSERT_STACK_USER_PRIV_KEY"
    pm_type: "pxe_ssh"
    cpus: $vcpus
    memory: $ramsize
    disk: 41
    arch: "x86_64"
    capabilities: "$capability"
EOF
  done

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
