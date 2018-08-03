##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import distro
import libvirt
import logging
import os
import xml.etree.ElementTree as ET

from apex.common.exceptions import OvercloudNodeException


class OvercloudNode:
    """
    Overcloud server
    """
    def __init__(self, role, ip, ovs_ctrlrs, ovs_mgrs, name, node_xml,
                 disk_img):
        self.role = role
        self.ip = ip
        self.ovs_ctrlrs = ovs_ctrlrs
        self.ovs_mgrs = ovs_mgrs
        self.name = name
        self.node_xml_file = node_xml
        self.node_xml = None
        self.vm = None
        self.disk_img = None
        if not os.path.isfile(self.node_xml_file):
            raise OvercloudNodeException('XML definition file not found: '
                                         '{}'.format(self.node_xml_file))
        if not os.path.isfile(disk_img):
            raise OvercloudNodeException('Disk image file not found: '
                                         '{}'.format(self.node_xml_file))
        self.conn = libvirt.open('qemu:///system')
        if not self.conn:
            raise OvercloudNodeException('Unable to open libvirt connection')

        self.create(src_disk=disk_img)

    def copy_disk(self, disk):
        # find default storage pool path

    @staticmethod
    def _update_xml(xml):
        try:
            etree = ET.fromstring(xml)
            type_element = etree.find('os').find('type')
            if 'machine' in type_element.keys():
                type_element.set('machine', 'pc')
                logging.debug('XML updated with machine "pc"')
                xml = ET.tostring(etree).decode('utf-8')
        except (AttributeError, ET.ParseError):
            logging.warning('Failure to parse XML and set machine type')

        # qemu-kvm path may differ per system, need to detect it and update xml
        linux_ver = distro.linux_distribution()[0]
        if linux_ver == 'Fedora':
            qemu_path = '/usr/bin/qemu-kvm'
        else:
            qemu_path = '/usr/libexec/qemu-kvm'

        try:
            etree = ET.fromstring(xml)
            etree.find('devices').find('emulator').text = qemu_path
            logging.debug('XML updated with emulator location: '
                          '{}'.format(qemu_path))
            xml = ET.tostring(etree).decode('utf-8')
        except (AttributeError, ET.ParseError):
            logging.warning('Failure to parse XML and update qemu path')

        return xml

    def create(self, src_disk):
        # copy disk to pool and get new disk location
        # TODO(trozet)
        logging.debug('Parsing node XML from {}'.format(self.node_xml_file))
        with open(self.node_xml_file, 'r') as fh:
            self.node_xml = fh.read()
        # if machine is not pc we need to set, also need to update qemu-kvm and
        # storage location
        self.node_xml = self._update_xml(self.node_xml)
        logging.info('Creating node {} in libvirt'.format(self.name))
        self.vm = self.conn.defineXML(self.node_xml)

    def start(self):
        """
        Boot node in libvirt
        :return:
        """
        self.vm.create()
