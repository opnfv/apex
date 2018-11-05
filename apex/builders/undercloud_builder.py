##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Used to modify undercloud qcow2 image
import logging
import os

from apex.common import constants as con
from apex.common import utils
from apex.virtual import utils as virt_utils


def add_upstream_packages(image):
    """
    Adds required base upstream packages to Undercloud for deployment
    :param image:
    :return: None
    """
    virt_ops = list()
    pkgs = [
        'epel-release',
        'openstack-utils',
        'ceph-common',
        'python2-networking-sfc',
        'openstack-ironic-inspector',
        'subunit-filters',
        'docker-distribution',
        'openstack-tripleo-validations',
        'libguestfs-tools',
        'ceph-ansible',
        'python-tripleoclient',
        'openstack-tripleo-heat-templates'
    ]

    for pkg in pkgs:
        virt_ops.append({con.VIRT_INSTALL: pkg})
    virt_utils.virt_customize(virt_ops, image)


def inject_calipso_installer(tmp_dir, image):
    """
    Downloads calipso installer script from artifacts.opnfv.org
    and puts it under /root/ for further installation process.
    :return:
    """
    calipso_file = os.path.basename(con.CALIPSO_INSTALLER_URL)
    calipso_url = con.CALIPSO_INSTALLER_URL.replace(calipso_file, '')
    utils.fetch_upstream_and_unpack(tmp_dir, calipso_url, [calipso_file])

    virt_ops = [
        {con.VIRT_UPLOAD: "{}/{}:/root/".format(tmp_dir, calipso_file)}]
    virt_utils.virt_customize(virt_ops, image)
    logging.info("Calipso injected into {}".format(image))

# TODO(trozet): add unit testing for calipso injector
# TODO(trozet): add rest of build for undercloud here as well


def update_repos(image, branch):
    virt_ops = [
        {con.VIRT_RUN_CMD: "rm /etc/yum.repos.d/delorean*",
         con.VIRT_RUN_CMD: "yum-config-manager --add-repo "
                           "https://trunk.rdoproject.org/centos7/{}"
                           "/delorean.repo".format(con.RDO_TAG),
         con.VIRT_INSTALL: "python-tripleo-repos",
         con.VIRT_RUN_CMD: "rm /etc/yum.repos.d/delorean*",
         con.VIRT_RUN_CMD: "tripleo-repos -b {} {} ceph".format(branch,
                                                                con.RDO_TAG)}
    ]
    virt_utils.virt_customize(virt_ops, image)
