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
import json
import os
import subprocess

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
    # Remove incompatible python-docker version
    virt_ops.append({con.VIRT_RUN_CMD: "yum remove -y python-docker-py"})

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
        {con.VIRT_RUN_CMD: "rm -f /etc/yum.repos.d/delorean*"},
        {con.VIRT_RUN_CMD: "yum-config-manager --add-repo "
                           "https://trunk.rdoproject.org/centos7/{}"
                           "/delorean.repo".format(con.RDO_TAG)},
        {con.VIRT_RUN_CMD: "yum clean all"},
        {con.VIRT_INSTALL: "python2-tripleo-repos"},
        {con.VIRT_RUN_CMD: "tripleo-repos -b {} {} ceph".format(branch,
                                                                con.RDO_TAG)}
    ]
    virt_utils.virt_customize(virt_ops, image)


def expand_disk(image, desired_size=50):
    """
    Expands a disk image to desired_size in GigaBytes
    :param image: image to resize
    :param desired_size: desired size in GB
    :return: None
    """
    # there is a lib called vminspect which has some dependencies and is
    # not yet available in pip. Consider switching to this lib later.
    try:
        img_out = json.loads(subprocess.check_output(
            ['qemu-img', 'info', '--output=json', image],
            stderr=subprocess.STDOUT).decode())
        disk_gb_size = int(img_out['virtual-size'] / 1000000000)
        if disk_gb_size < desired_size:
            logging.info("Expanding disk image: {}. Current size: {} is less"
                         "than require size: {}".format(image, disk_gb_size,
                                                        desired_size))
            diff_size = desired_size - disk_gb_size
            subprocess.check_call(['qemu-img', 'resize', image,
                                   "+{}G".format(diff_size)],
                                  stderr=subprocess.STDOUT)

    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) \
            as e:
        logging.warning("Unable to resize disk, disk may not be large "
                        "enough: {}".format(e))
