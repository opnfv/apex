##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Used to modify undercloud qcow2 image

from apex.common import constants as con
from apex.virtual import utils as virt_utils


def add_upstream_packages(image):
    """
    Adds required base upstream packages to Undercloud for deployment
    :param image:
    :return: None
    """
    virt_ops = list()
    pkgs = [
        'openstack-utils',
        'ceph-common',
        'python2-networking-sfc',
        'openstack-ironic-inspector',
        'subunit-filters',
        'docker-distribution',
        'openstack-tripleo-validations',
        'libguestfs-tools',
    ]

    for pkg in pkgs:
        virt_ops.append({con.VIRT_INSTALL: pkg})
    virt_utils.virt_customize(virt_ops, image)

# TODO(trozet): add rest of build for undercloud here as well
