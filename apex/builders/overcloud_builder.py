##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Used to modify overcloud qcow2 image

import logging
import os
import tarfile

import apex.builders.common_builder
from apex.common import constants as con
from apex.common import utils as utils
from apex.common.exceptions import ApexBuildException
from apex.virtual import utils as virt_utils


def inject_opendaylight(odl_version, image, tmp_dir, uc_ip,
                        os_version, docker_tag=None):
    assert odl_version in con.VALID_ODL_VERSIONS
    # add repo
    if odl_version == 'master':
        odl_pkg_version = con.VALID_ODL_VERSIONS[-2]
        branch = odl_version
    else:
        odl_pkg_version = odl_version
        branch = "stable/{}".format(odl_version)
    odl_url = "https://nexus.opendaylight.org/content/repositories" \
              "/opendaylight-{}-epel-7-x86_64-devel/".format(odl_pkg_version)
    repo_name = "opendaylight-{}".format(odl_pkg_version)
    apex.builders.common_builder.add_repo(odl_url, repo_name, image, tmp_dir)
    # download puppet-opendaylight
    archive = apex.builders.common_builder.create_git_archive(
        repo_url=con.PUPPET_ODL_URL, repo_name='puppet-opendaylight',
        tmp_dir=tmp_dir, branch=branch, prefix='opendaylight/')
    # install ODL, puppet-odl
    virt_ops = [
        {con.VIRT_UPLOAD: "{}:/etc/puppet/modules/".format(archive)},
        {con.VIRT_RUN_CMD: 'rm -rf /etc/puppet/modules/opendaylight'},
        {con.VIRT_RUN_CMD: "cd /etc/puppet/modules/ && tar xvf "
                           "puppet-opendaylight.tar"},
        {con.VIRT_INSTALL: "java-1.8.0-openjdk"}
    ]
    if docker_tag:
        docker_cmds = [
            "RUN yum remove opendaylight -y",
            "RUN echo $'[opendaylight]\\n\\",
            "baseurl={}\\n\\".format(odl_url),
            "gpgcheck=0\\n\\",
            "enabled=1' > /etc/yum.repos.d/opendaylight.repo",
            "RUN yum -y install opendaylight"
        ]
        src_img_uri = "{}:8787/tripleo{}/centos-binary-{}:" \
                      "{}".format(uc_ip, os_version, 'opendaylight',
                                  docker_tag)
        build_dockerfile('opendaylight', tmp_dir, docker_cmds, src_img_uri)
    else:
        virt_ops.append({con.VIRT_INSTALL: 'opendaylight'})
    virt_utils.virt_customize(virt_ops, image)
    logging.info("OpenDaylight injected into {}".format(image))


def inject_quagga(image, tmp_dir):
    """
    Downloads quagga tarball from artifacts.opnfv.org
    and install it on the overcloud image on the fly.
    :param image:
    :param tmp_dir:
    :return:
    """
    utils.fetch_upstream_and_unpack(tmp_dir,
                                    os.path.split(con.QUAGGA_URL)[0] + "/",
                                    [os.path.basename(con.QUAGGA_URL)])

    virt_ops = [
        {con.VIRT_UPLOAD: "{}/quagga-4.tar.gz:/root/".format(tmp_dir)},
        {con.VIRT_RUN_CMD: "cd /root/ && tar xzf quagga-4.tar.gz"},
        {con.VIRT_RUN_CMD: "cd /root/quagga;packages=$(ls |grep -vE 'debug"
         "info|devel|contrib');yum -y install $packages"}
    ]
    virt_utils.virt_customize(virt_ops, image)
    logging.info("Quagga injected into {}".format(image))


def inject_ovs_nsh(image, tmp_dir):
    """
    Downloads OpenVswitch, compiles it and installs it on the
    overcloud image on the fly.
    :param image:
    :param tmp_dir:
    :return:
    """
    ovs_filename = os.path.basename(con.OVS_URL)
    ovs_folder = ovs_filename[:17]
    utils.fetch_upstream_and_unpack(tmp_dir,
                                    os.path.split(con.OVS_URL)[0] + "/",
                                    [ovs_filename])

    virt_ops = [
        {con.VIRT_UPLOAD: "{}:/root/".format(tmp_dir + "/" + ovs_filename)},
        {con.VIRT_INSTALL: "rpm-build,autoconf,automake,libtool,openssl"
         "openssl-devel,python,python-twisted-core,python-six,groff,graphviz"
         "python-zope-interface,desktop-file-utils,procps-ng,PyQt4,"
         "libcap-ng,libcap-ng-devel,selinux-policy-devel,kernel-devel,"
         "kernel-headers,kernel-tools,rpmdevtools,systemd-units,python-devel,"
         "python-sphinx"},
        {con.VIRT_RUN_CMD: "cd /root/ && tar xzf {}".format(ovs_filename)},
        {con.VIRT_UPLOAD:
         "{}/build_ovs_nsh.sh:/root/{}".format(tmp_dir, ovs_folder)},
        {con.VIRT_RUN_CMD:
         "cd /root/{0} && chmod -R 777 * && chown -R root:root * && "
         "./build_ovs_nsh.sh && rpm -Uhv --force rpm/rpmbuild/RPMS/x86_64/{0}"
         "-1.el7.x86_64.rpm && rpm -Uhv -force rpm/rpmbuild/RPMS/x86_64"
         "/openvswitch-kmod{1}-1.el7.centos.x86_64.rpm".format(
             ovs_folder, ovs_folder[11:17])}
    ]
    virt_utils.virt_customize(virt_ops, image)
    logging.info("OVS injected into {}".format(image))


def build_dockerfile(service, tmp_dir, docker_cmds, src_image_uri):
    """
    Builds docker file per service and stores it in a
    tmp_dir/containers/<service> directory.  If the Dockerfile already exists,
    simply append the docker cmds to it.
    :param service: name of sub-directory to store Dockerfile in
    :param tmp_dir: Temporary directory to store the container's dockerfile in
    :param docker_cmds: List of commands to insert into the dockerfile
    :param src_image_uri: Docker URI format for where the source image exists
    :return: None
    """
    logging.debug("Building Dockerfile for {} with docker_cmds: {}".format(
        service, docker_cmds))
    c_dir = os.path.join(tmp_dir, 'containers')
    service_dir = os.path.join(c_dir, service)
    if not os.path.isdir(service_dir):
        os.makedirs(service_dir, exist_ok=True)
    from_cmd = "FROM {}\n".format(src_image_uri)
    service_file = os.path.join(service_dir, 'Dockerfile')
    assert isinstance(docker_cmds, list)
    if os.path.isfile(service_file):
        append_cmds = True
    else:
        append_cmds = False
    with open(service_file, "a+") as fh:
        if not append_cmds:
            fh.write(from_cmd)
        fh.write('\n'.join(docker_cmds))


def archive_docker_patches(tmp_dir):
    """
    Archives Overcloud docker patches into a tar file for upload to Undercloud
    :param tmp_dir: temporary directory where containers folder is stored
    :return: None
    """
    container_path = os.path.join(tmp_dir, 'containers')
    if not os.path.isdir(container_path):
        raise ApexBuildException("Docker directory for patches not found: "
                                 "{}".format(container_path))
    archive_file = os.path.join(tmp_dir, 'docker_patches.tar.gz')
    with tarfile.open(archive_file, "w:gz") as tar:
        tar.add(container_path, arcname=os.path.basename(container_path))
