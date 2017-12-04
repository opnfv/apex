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
    # FIXME(trozet): we have to lock to this beta ceph ansible package because
    # the current RPM versioning is wrong and an older package has a higher
    # version than this package.  We should change to just 'ceph-ansible'
    # once the package/repo has been fixed.  Note: luminous is fine here
    # because Apex will only support container deployment for Queens and later
    pkgs = [
        'openstack-utils',
        'ceph-common',
        'python2-networking-sfc',
        'openstack-ironic-inspector',
        'subunit-filters',
        'docker-distribution',
        'openstack-tripleo-validations',
        'libguestfs-tools',
        'http://mirror.centos.org/centos/7/storage/x86_64/ceph-luminous' +
        '/ceph-ansible-3.1.0-0.beta3.1.el7.noarch.rpm'
    ]

    for pkg in pkgs:
        virt_ops.append({con.VIRT_INSTALL: pkg})
    virt_utils.virt_customize(virt_ops, image)

# TODO(trozet): add rest of build for undercloud here as well
