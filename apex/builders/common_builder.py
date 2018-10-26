##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Common building utilities for undercloud and overcloud

import datetime
import git
import json
import logging
import os
import platform
import pprint
import re
import urllib.parse
import yaml

import apex.builders.overcloud_builder as oc_builder
from apex import build_utils
from apex.builders import exceptions as exc
from apex.common import constants as con
from apex.common import utils
from apex.virtual import utils as virt_utils


def project_to_path(project, patch=None):
    """
    Translates project to absolute file path to use in patching
    :param project: name of project
    :param patch: the patch to applied to the project
    :return: File path
    """
    if project.startswith('openstack/'):
        project = os.path.basename(project)
    if 'puppet' in project:
        return "/etc/puppet/modules/{}".format(project.replace('puppet-', ''))
    elif 'tripleo-heat-templates' in project:
        return "/usr/share/openstack-tripleo-heat-templates"
    elif ('tripleo-common' in project and
          build_utils.is_path_in_patch(patch, 'container-images/')):
        # tripleo-common has python and another component to it
        # here we detect if there is a change to the yaml component and if so
        # treat it like it is not python. This has the caveat of if there
        # is a patch to both python and yaml this will not work
        # FIXME(trozet): add ability to split tripleo-common patches that
        # modify both python and yaml
        return "/usr/share/openstack-tripleo-common-containers/"
    else:
        # assume python.  python patches will apply to a project name subdir.
        # For example, python-tripleoclient patch will apply to the
        # tripleoclient directory, which is the directory extracted during
        # python install into the PYTHONPATH.  Therefore we need to just be
        # in the PYTHONPATH directory to apply a patch
        return "/usr/lib/python2.7/site-packages/"


def project_to_docker_image(project):
    """
    Translates OpenStack project to OOO services that are containerized
    :param project: name of OpenStack project
    :return: List of OOO docker service names
    """
    # Fetch all docker containers in docker hub with tripleo and filter
    # based on project

    hub_output = utils.open_webpage(
        urllib.parse.urljoin(con.DOCKERHUB_OOO, '?page_size=1024'), timeout=10)
    try:
        results = json.loads(hub_output.decode())['results']
    except Exception as e:
        logging.error("Unable to parse docker hub output for"
                      "tripleoupstream repository")
        logging.debug("HTTP response from dockerhub:\n{}".format(hub_output))
        raise exc.ApexCommonBuilderException(
            "Failed to parse docker image info from Docker Hub: {}".format(e))
    logging.debug("Docker Hub tripleoupstream entities found: {}".format(
        results))
    docker_images = list()
    for result in results:
        if result['name'].startswith("centos-binary-{}".format(project)):
            # add as docker image shortname (just service name)
            docker_images.append(result['name'].replace('centos-binary-', ''))

    return docker_images


def is_patch_promoted(change, branch, docker_image=None):
    """
    Checks to see if a patch that is in merged exists in either the docker
    container or the promoted tripleo images
    :param change: gerrit change json output
    :param branch: branch to use when polling artifacts (does not include
    stable prefix)
    :param docker_image: container this applies to if (defaults to None)
    :return: True if the patch exists in a promoted artifact upstream
    """
    assert isinstance(change, dict)
    assert 'status' in change

    # if not merged we already know this is not closed/abandoned, so we know
    # this is not promoted
    if change['status'] != 'MERGED':
        return False
    assert 'submitted' in change
    # drop microseconds cause who cares
    stime = re.sub('\..*$', '', change['submitted'])
    submitted_date = datetime.datetime.strptime(stime, "%Y-%m-%d %H:%M:%S")
    # Patch applies to overcloud/undercloud
    if docker_image is None:
        oc_url = urllib.parse.urljoin(
            con.UPSTREAM_RDO.replace('master', branch), 'overcloud-full.tar')
        oc_mtime = utils.get_url_modified_date(oc_url)
        if oc_mtime > submitted_date:
            logging.debug("oc image was last modified at {}, which is"
                          "newer than merge date: {}".format(oc_mtime,
                                                             submitted_date))
            return True
    else:
        # must be a docker patch, check docker tag modified time
        docker_url = con.DOCKERHUB_OOO.replace('tripleomaster',
                                               "tripleo{}".format(branch))
        url_path = "{}/tags/{}".format(docker_image, con.DOCKER_TAG)
        docker_url = urllib.parse.urljoin(docker_url, url_path)
        logging.debug("docker url is: {}".format(docker_url))
        docker_output = utils.open_webpage(docker_url, 10)
        logging.debug('Docker web output: {}'.format(docker_output))
        hub_mtime = json.loads(docker_output.decode())['last_updated']
        hub_mtime = re.sub('\..*$', '', hub_mtime)
        # docker modified time is in this format '2018-06-11T15:23:55.135744Z'
        # and we drop microseconds
        hub_dtime = datetime.datetime.strptime(hub_mtime, "%Y-%m-%dT%H:%M:%S")
        if hub_dtime > submitted_date:
            logging.debug("docker image: {} was last modified at {}, which is"
                          "newer than merge date: {}".format(docker_image,
                                                             hub_dtime,
                                                             submitted_date))
            return True
    return False


def add_upstream_patches(patches, image, tmp_dir,
                         default_branch=os.path.join('stable',
                                                     con.DEFAULT_OS_VERSION),
                         uc_ip=None, docker_tag=None):
    """
    Adds patches from upstream OpenStack gerrit to Undercloud for deployment
    :param patches: list of patches
    :param image: undercloud image
    :param tmp_dir: to store temporary patch files
    :param default_branch: default branch to fetch commit (if not specified
    in patch)
    :param uc_ip: undercloud IP (required only for docker patches)
    :param docker_tag: Docker Tag (required only for docker patches)
    :return: Set of docker services patched (if applicable)
    """
    virt_ops = [{con.VIRT_INSTALL: 'patch'}]
    logging.debug("Evaluating upstream patches:\n{}".format(patches))
    docker_services = set()
    for patch in patches:
        assert isinstance(patch, dict)
        assert all(i in patch.keys() for i in ['project', 'change-id'])
        if 'branch' in patch.keys():
            branch = patch['branch']
        else:
            branch = default_branch
        patch_diff = build_utils.get_patch(patch['change-id'],
                                           patch['project'], branch)
        project_path = project_to_path(patch['project'], patch_diff)
        # If docker tag and python we know this patch belongs on docker
        # container for a docker service. Therefore we build the dockerfile
        # and move the patch into the containers directory.  We also assume
        # this builder call is for overcloud, because we do not support
        # undercloud containers
        if docker_tag and 'python' in project_path:
            # Projects map to multiple THT services, need to check which
            # are supported
            ooo_docker_services = project_to_docker_image(patch['project'])
            docker_img = ooo_docker_services[0]
        else:
            ooo_docker_services = []
            docker_img = None
        change = build_utils.get_change(con.OPENSTACK_GERRIT,
                                        patch['project'], branch,
                                        patch['change-id'])
        patch_promoted = is_patch_promoted(change,
                                           branch.replace('stable/', ''),
                                           docker_img)

        if patch_diff and not patch_promoted:
            patch_file = "{}.patch".format(patch['change-id'])
            # If we found services, then we treat the patch like it applies to
            # docker only
            if ooo_docker_services:
                os_version = default_branch.replace('stable/', '')
                for service in ooo_docker_services:
                    docker_services = docker_services.union({service})
                    docker_cmds = [
                        "WORKDIR {}".format(project_path),
                        "ADD {} {}".format(patch_file, project_path),
                        "RUN patch -p1 < {}".format(patch_file)
                    ]
                    src_img_uri = "{}:8787/tripleo{}/centos-binary-{}:" \
                                  "{}".format(uc_ip, os_version, service,
                                              docker_tag)
                    oc_builder.build_dockerfile(service, tmp_dir, docker_cmds,
                                                src_img_uri)
                patch_file_path = os.path.join(tmp_dir, 'containers',
                                               patch_file)
            else:
                patch_file_path = os.path.join(tmp_dir, patch_file)
                virt_ops.extend([
                    {con.VIRT_UPLOAD: "{}:{}".format(patch_file_path,
                                                     project_path)},
                    {con.VIRT_RUN_CMD: "cd {} && patch -p1 < {}".format(
                        project_path, patch_file)}])
                logging.info("Adding patch {} to {}".format(patch_file,
                                                            image))
            with open(patch_file_path, 'w') as fh:
                fh.write(patch_diff)
        else:
            logging.info("Ignoring patch:\n{}".format(patch))
    if len(virt_ops) > 1:
        virt_utils.virt_customize(virt_ops, image)
    return docker_services


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


def get_neutron_driver(ds_opts):
    sdn = ds_opts.get('sdn_controller', None)
    for controllers in 'opendaylight', 'ovn':
        if sdn == controllers:
            return sdn

    if ds_opts.get('vpp', False):
        return 'vpp'

    return None


def prepare_container_images(prep_file, branch='master', neutron_driver=None):
    if not os.path.isfile(prep_file):
        raise exc.ApexCommonBuilderException("Prep file does not exist: "
                                             "{}".format(prep_file))
    with open(prep_file) as fh:
        data = yaml.safe_load(fh)
    try:
        p_set = data['parameter_defaults']['ContainerImagePrepare'][0]['set']
        if neutron_driver:
            p_set['neutron_driver'] = neutron_driver
        p_set['namespace'] = "docker.io/tripleo{}".format(branch)
        if platform.machine() == 'aarch64':
            p_set['ceph_tag'] = 'master-fafda7d-luminous-centos-7-aarch64'

    except KeyError:
        logging.error("Invalid prep file format: {}".format(prep_file))
        raise exc.ApexCommonBuilderException("Invalid format for prep file")

    logging.debug("Writing new container prep file:\n{}".format(
        pprint.pformat(data)))
    with open(prep_file, 'w') as fh:
        yaml.safe_dump(data, fh, default_flow_style=False)
