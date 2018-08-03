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
import shutil
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

    def _configure_disk(self, disk):
        # find default storage pool path
        pool = self.conn.storagePoolLookupByName('default')
        if pool is None:
            raise OvercloudNodeException('Cannot find default storage pool')
        pool_xml = pool.XMLDesc()
        logging.debug('Default storage pool xml: {}'.format(pool_xml))
        etree = ET.fromstring(pool_xml)
        try:
            path = etree.find('target').find('path').text
            logging.info('System libvirt default pool path: {}'.format(path))
        except AttributeError as e:
            logging.error('Failure to find libvirt storage path: {}'.format(
                e))
            raise OvercloudNodeException('Cannot find default storage path')
        # copy disk to system path
        self.disk_img = os.path.join(path, os.path.basename(disk))
        logging.info('Copying disk image to: {}. This may take some '
                     'time...'.format(self.disk_img))
        shutil.copyfile(disk, self.disk_img)

    @staticmethod
    def _update_xml(xml, disk_path=None):
        logging.debug('Parsing xml')
        try:
            etree = ET.fromstring(xml)
        except ET.ParseError:
            logging.error('Unable to parse node XML: {}'.format(xml))
            raise OvercloudNodeException('Unable to parse node XML')

        try:
            type_element = etree.find('os').find('type')
            if 'machine' in type_element.keys():
                type_element.set('machine', 'pc')
                logging.debug('XML updated with machine "pc"')
        except AttributeError:
            logging.warning('Failure to set XML machine type')

        # qemu-kvm path may differ per system, need to detect it and update xml
        linux_ver = distro.linux_distribution()[0]
        if linux_ver == 'Fedora':
            qemu_path = '/usr/bin/qemu-kvm'
        else:
            qemu_path = '/usr/libexec/qemu-kvm'

        try:
            etree.find('devices').find('emulator').text = qemu_path
            logging.debug('XML updated with emulator location: '
                          '{}'.format(qemu_path))
            xml = ET.tostring(etree).decode('utf-8')
        except AttributeError:
            logging.warning('Failure to update XML qemu path')

        if disk_path:
            try:
                disk_element = etree.find('devices').find('disk').find(
                    'source')
                disk_element.set('file', disk_path)
                logging.debug('XML updated with file path: {}'.format(
                    disk_path))
            except AttributeError:
                logging.warning('Failure to parse XML and set machine type')

        return ET.tostring(etree).decode('utf-8')

    def create(self, src_disk):
        # copy disk to pool and get new disk location
        logging.debug('Preparing disk image')
        self._configure_disk(src_disk)
        logging.debug('Parsing node XML from {}'.format(self.node_xml_file))
        with open(self.node_xml_file, 'r') as fh:
            self.node_xml = fh.read()
        # if machine is not pc we need to set, also need to update qemu-kvm and
        # storage location
        self.node_xml = self._update_xml(self.node_xml, self.disk_img)
        logging.info('Creating node {} in libvirt'.format(self.name))
        self.vm = self.conn.defineXML(self.node_xml)

    def start(self):
        """
        Boot node in libvirt
        :return:
        """
        self.vm.create()
