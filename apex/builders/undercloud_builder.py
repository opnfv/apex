##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Used to modify undercloud qcow2 image
import os

from apex import build_utils
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


def project_to_path(project):
    """
    Translates project to absolute file path
    :param project: name of project
    :return: File path
    """
    if project.startswith('openstack/'):
        project = os.path.basename(project)
    if 'puppet' in project:
        return "/etc/puppet/modules/{}".format(project.replace('puppet-', ''))
    elif 'tripleo-heat-templates' in project:
        return "/usr/share/openstack-tripleo-heat-templates"
    else:
        # assume python
        return "/usr/lib/python2.7/site-packages/{}".format(project)


def add_upstream_patches(patches, image, tmp_dir):
    """
    Adds patches from upstream OpenStack gerrit to Undercloud for deployment
    :param patches: list of patches
    :param image: undercloud image
    :param tmp_dir: to store temporary patch files
    :return: None
    """
    virt_ops = list()
    for patch in patches:
        assert patch is dict
        assert all('project', 'change-id') in patch.keys()
        patch_diff = build_utils.get_patch(patch['change-id'],
                                           patch['project'])
        if patch_diff:
            patch_file = os.path.join(tmp_dir,
                                      "{}.patch".format(patch['change-id']))
            with open(patch_file, 'w') as fh:
                fh.write(patch_diff)
            project_path = project_to_path(patch['project'])
            virt_ops.extend([
                {con.VIRT_UPLOAD: "{}:{}".format(patch_file, project_path)},
                {con.VIRT_RUN_CMD: "cd {} && patch -p1 < {}".format(
                    project_path, patch_file)}])
    virt_utils.virt_customize(virt_ops, image)


# TODO(trozet): add rest of build for undercloud here as well
