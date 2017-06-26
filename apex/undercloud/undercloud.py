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


class ApexUndercloudException(Exception):
    pass


class Undercloud:
    """
    This class represents an Apex Undercloud VM
    """
    def __init__(self, root_pw=None):
        self.exists = False
        self.active = False
        self.ip = None
        self.root_pw = root_pw

        self._get_state()
        if self.exists:
            logging.error("Undercloud VM already exists.  Please clean "
                          "before creating")
            raise ApexUndercloudException("Undercloud VM already exists!")

    def _get_state(self):
        """
        Does an undercloud VM already exist on this host
        :return:
        """
        conn = libvirt.open('qemu:///system')
        try:
            vm = conn.lookupByName('undercloud')
            self.exists = True
            if vm.isActive():
                self.active = True
        except libvirt.libvirtError:
            logging.debug("No undercloud VM exists")

    def create(self):
        self.setup_volumes()
        self.inject_auth()

    def configure(self):
        """
        Configures undercloud VM
        :return:
        """
        # configure all settings
        # install undercloud
        # attach external network

        pass

    def setup_volumes(self):
        # cp disks
        # check if resize needed
        pass

    def inject_auth(self):
        # virt-customize keys/pws
        pass




