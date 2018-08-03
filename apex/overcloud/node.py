##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


class overcloudNode:
    """
    Overcloud server
    """
    def __init__(self, role, ip=None):
        self.role = role
        self.ip - ip

    def start(self):
        """
        Boot node in libvirt
        :return:
        """
        pass
