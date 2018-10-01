##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import libvirt
import logging
import math
import os
import platform
import random

MAX_NUM_MACS = math.trunc(0xff / 2)


def generate_baremetal_macs(count=1):
    """Generate an Ethernet MAC address suitable for baremetal testing."""
    # NOTE(dprince): We generate our own bare metal MAC address's here
    # instead of relying on libvirt so that we can ensure the
    # locally administered bit is set low. (The libvirt default is
    # to set the 2nd MSB high.) This effectively allows our
    # fake baremetal VMs to more accurately behave like real hardware
    # and fixes issues with bridge/DHCP configurations which rely
    # on the fact that bridges assume the MAC address of the lowest
    # attached NIC.
    # MACs generated for a given machine will also be in sequential
    # order, which matches how most BM machines are laid out as well.
    # Additionally we increment each MAC by two places.
    macs = []

    if count > MAX_NUM_MACS:
        raise ValueError("The MAX num of MACS supported is %i." % MAX_NUM_MACS)

    base_nums = [0x00,
                 random.randint(0x00, 0xff),
                 random.randint(0x00, 0xff),
                 random.randint(0x00, 0xff),
                 random.randint(0x00, 0xff)]
    base_mac = ':'.join(map(lambda x: "%02x" % x, base_nums))

    start = random.randint(0x00, 0xff)
    if (start + (count * 2)) > 0xff:
        # leave room to generate macs in sequence
        start = 0xff - count * 2
    for num in range(0, count * 2, 2):
        mac = start + num
        macs.append(base_mac + ":" + ("%02x" % mac))
    return macs


def create_vm_storage(domain, vol_path='/var/lib/libvirt/images'):
    volume_name = domain + '.qcow2'
    stgvol_xml = """
    <volume>
      <name>{}</name>
      <allocation>0</allocation>
      <capacity unit="G">41</capacity>
      <target>
        <format type='qcow2'/>
        <path>{}</path>
        <permissions>
          <owner>107</owner>
          <group>107</group>
          <mode>0744</mode>
          <label>virt_image_t</label>
        </permissions>
      </target>
    </volume>""".format(volume_name, os.path.join(vol_path, volume_name))

    conn = libvirt.open('qemu:///system')
    pool = conn.storagePoolLookupByName('default')
    if pool is None:
        raise Exception("Default libvirt storage pool missing")
        # TODO(trozet) create default storage pool

    if pool.isActive() == 0:
        pool.create()
    try:
        vol = pool.storageVolLookupByName(volume_name)
        vol.wipe(0)
        vol.delete(0)
    except libvirt.libvirtError as e:
        if e.get_error_code() != libvirt.VIR_ERR_NO_STORAGE_VOL:
            raise
    new_vol = pool.createXML(stgvol_xml)
    if new_vol is None:
        raise Exception("Unable to create new volume")
    logging.debug("Created new storage volume: {}".format(volume_name))


def create_vm(name, image, diskbus='sata', baremetal_interfaces=['admin'],
              arch=platform.machine(), engine='kvm', memory=8192,
              bootdev='network', cpus=4, nic_driver='virtio', macs=[],
              direct_boot=None, kernel_args=None, default_network=False,
              template_dir='/usr/share/opnfv-apex'):
    # TODO(trozet): fix name here to be image since it is full path of qcow2
    create_vm_storage(name)
    with open(os.path.join(template_dir, 'domain.xml'), 'r') as f:
        source_template = f.read()
    imagefile = os.path.realpath(image)

    # ARMband: Bypass default VM config for  aarch64
    if arch == 'aarch64' and diskbus == 'sata':
        diskbus = 'virtio'
        memory = 32768
        cpus = 16

    memory = int(memory) * 1024
    params = {
        'name': name,
        'imagefile': imagefile,
        'engine': engine,
        'arch': arch,
        'memory': str(memory),
        'cpus': str(cpus),
        'bootdev': bootdev,
        'network': '',
        'enable_serial_console': '',
        'direct_boot': '',
        'kernel_args': '',
        'user_interface': '',
    }

    # Configure the bus type for the target disk device
    params['diskbus'] = diskbus
    nicparams = {
        'nicdriver': nic_driver,
    }
    if default_network:
        params['network'] = """
      <!-- regular natted network, for access to the vm -->
      <interface type='network'>
        <source network='default'/>
        <model type='%(nicdriver)s'/>
      </interface>""" % nicparams
    else:
        params['network'] = ''
    while len(macs) < len(baremetal_interfaces):
        macs += generate_baremetal_macs(1)

    params['bm_network'] = ""
    for bm_interface, mac in zip(baremetal_interfaces, macs):
        bm_interface_params = {
            'bminterface': bm_interface,
            'bmmacaddress': mac,
            'nicdriver': nic_driver,
        }
        params['bm_network'] += """
          <!-- bridged 'bare metal' network on %(bminterface)s -->
          <interface type='network'>
            <mac address='%(bmmacaddress)s'/>
            <source network='%(bminterface)s'/>
            <model type='%(nicdriver)s'/>
          </interface>""" % bm_interface_params

    if direct_boot:
        params['direct_boot'] = """
        <kernel>/var/lib/libvirt/images/%(direct_boot)s.vmlinuz</kernel>
        <initrd>/var/lib/libvirt/images/%(direct_boot)s.initrd</initrd>
        """ % {'direct_boot': direct_boot}
    if kernel_args:
        params['kernel_args'] = """
        <cmdline>%s</cmdline>
        """ % ' '.join(kernel_args)

    if arch == 'aarch64':
        params['direct_boot'] += """
        <loader readonly='yes' \
        type='pflash'>/usr/share/AAVMF/AAVMF_CODE.fd</loader>
        <nvram>/var/lib/libvirt/qemu/nvram/centos7.0_VARS.fd</nvram>
        """
        params['user_interface'] = """
        <controller type='virtio-serial' index='0'>
          <address type='pci'/>
        </controller>
        <serial type='pty'>
          <target port='0'/>
        </serial>
        <console type='pty'>
          <target type='serial' port='0'/>
        </console>
        <channel type='unix'>
          <target type='virtio' name='org.qemu.guest_agent.0'/>
          <address type='virtio-serial' controller='0' bus='0' port='1'/>
        </channel>
        """
    else:
        params['enable_serial_console'] = """
        <serial type='pty'>
          <target port='0'/>
        </serial>
        <console type='pty'>
          <target type='serial' port='0'/>
        </console>
        """
        params['user_interface'] = """
        <input type='mouse' bus='ps2'/>
        <graphics type='vnc' port='-1' autoport='yes'/>
        <video>
          <model type='cirrus' vram='9216' heads='1'/>
        </video>
        """

    libvirt_template = source_template % params
    logging.debug("libvirt template is {}".format(libvirt_template))
    conn = libvirt.open('qemu:///system')
    vm = conn.defineXML(libvirt_template)
    logging.info("Created machine %s with UUID %s" % (name, vm.UUIDString()))
    return vm
