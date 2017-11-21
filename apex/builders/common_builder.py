##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Common building utilities for undercloud and overcloud

import git
import logging
import os

from apex import build_utils
from apex.common import constants as con
from apex.virtual import utils as virt_utils


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


def add_upstream_patches(patches, image, tmp_dir,
                         default_branch=os.path.join('stable',
                                                     con.DEFAULT_OS_VERSION)):
    """
    Adds patches from upstream OpenStack gerrit to Undercloud for deployment
    :param patches: list of patches
    :param image: undercloud image
    :param tmp_dir: to store temporary patch files
    :param default_branch: default branch to fetch commit (if not specified
    in patch)
    :return: None
    """
    virt_ops = [{con.VIRT_INSTALL: 'patch'}]
    logging.debug("Evaluating upstream patches:\n{}".format(patches))
    for patch in patches:
        assert isinstance(patch, dict)
        assert all(i in patch.keys() for i in ['project', 'change-id'])
        if 'branch' in patch.keys():
            branch = patch['branch']
        else:
            branch = default_branch
        patch_diff = build_utils.get_patch(patch['change-id'],
                                           patch['project'], branch)
        if patch_diff:
            patch_file = "{}.patch".format(patch['change-id'])
            patch_file_path = os.path.join(tmp_dir, patch_file)
            with open(patch_file_path, 'w') as fh:
                fh.write(patch_diff)
            project_path = project_to_path(patch['project'])
            virt_ops.extend([
                {con.VIRT_UPLOAD: "{}:{}".format(patch_file_path,
                                                 project_path)},
                {con.VIRT_RUN_CMD: "cd {} && patch -p1 < {}".format(
                    project_path, patch_file)}])
            logging.info("Adding patch {} to {}".format(patch_file,
                                                        image))
        else:
            logging.info("Ignoring patch:\n{}".format(patch))
    if len(virt_ops) > 1:
        virt_utils.virt_customize(virt_ops, image)


def add_repo(repo_url, repo_name, image, tmp_dir):
    assert repo_name is not None
    assert repo_url is not None
    repo_file = "{}.repo".format(repo_name)
    repo_file_path = os.path.join(tmp_dir, repo_file)
    content = [
        "[{}]".format(repo_name),
        "name={}".format(repo_name),
        "baseurl={}".format(repo_url),
        "gpgcheck=0"
    ]
    logging.debug("Creating repo file {}".format(repo_name))
    with open(repo_file_path, 'w') as fh:
        fh.writelines("{}\n".format(line) for line in content)
    logging.debug("Adding repo {} to {}".format(repo_file, image))
    virt_utils.virt_customize([
        {con.VIRT_UPLOAD: "{}:/etc/yum.repos.d/".format(repo_file_path)}],
        image
    )


def create_git_archive(repo_url, repo_name, tmp_dir,
                       branch='master', prefix=''):
    repo = git.Repo.clone_from(repo_url, os.path.join(tmp_dir, repo_name))
    repo_git = repo.git
    if branch != str(repo.active_branch):
        repo_git.checkout("origin/{}".format(branch))
    archive_path = os.path.join(tmp_dir, "{}.tar".format(repo_name))
    with open(archive_path, 'wb') as fh:
        repo.archive(fh, prefix=prefix)
    logging.debug("Wrote archive file: {}".format(archive_path))
    return archive_path
