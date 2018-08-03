##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import libvirt
import logging
import os
import xml.etree.ElementTree as ET

from apex.common.exceptions import OvercloudNodeException


class OvercloudNode:
    """
    Overcloud server
    """
    def __init__(self, role, ip, ovs_ctrlrs, ovs_mgrs, name, node_xml):
        self.role = role
        self.ip = ip
        self.ovs_ctrlrs = ovs_ctrlrs
        self.ovs_mgrs = ovs_mgrs
        self.name = name
        self.node_xml_file = node_xml
        self.node_xml = None
        self.vm = None
        if not os.path.isfile(self.node_xml_file):
            raise OvercloudNodeException('XML definition file not found: '
                                         '{}'.format(self.node_xml_file))
        self.conn = libvirt.open('qemu:///system')
        if not self.conn:
            raise OvercloudNodeException('Unable to open libvirt connection')

        self.create()

    @staticmethod
    def _set_xml_machine(xml):
        try:
            type_element = xml.find('os').find('type')
            if 'machine' in type_element.keys():
                type_element.set('machine', 'pc')
                logging.debug('XML updated with machine "pc"')
        except AttributeError:
            logging.warning('Failure to parse XML and set machine type')

        return xml

    def create(self):
        logging.debug('Parsing node XML from {}'.format(self.node_xml_file))
        with open(self.node_xml_file, 'r') as fh:
            self.node_xml = ET.fromstring(fh.read())
        # if machine is not pc we need to set
        self.node_xml = self._set_xml_machine(self.node_xml)
        logging.info('Creating node {} in libvirt'.format(self.name))
        self.vm = self.conn.defineXML(self.node_xml)

    def start(self):
        """
        Boot node in libvirt
        :return:
        """
        self.vm.start()
