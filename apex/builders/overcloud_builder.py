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

from apex.builders import common_builder as c_builder
from apex.common import constants as con
from apex.virtual import utils as virt_utils

PUPPET_ODL_URL = 'https://git.opendaylight.org/gerrit/integration/packaging' \
                 '/puppet-opendaylight'


def inject_opendaylight(odl_version, image, tmp_dir):
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
    c_builder.add_repo(odl_url, repo_name, image, tmp_dir)
    # download puppet-opendaylight
    archive = c_builder.create_git_archive(
        repo_url=PUPPET_ODL_URL, repo_name='puppet-opendaylight',
        tmp_dir=tmp_dir, branch=branch, prefix='opendaylight/')
    # install ODL, puppet-odl
    virt_ops = [
        {con.VIRT_INSTALL: 'opendaylight'},
        {con.VIRT_UPLOAD: "{}:/etc/puppet/modules/".format(archive)},
        {con.VIRT_RUN_CMD: "cd /etc/puppet/modules/ && tar xvf "
                           "puppet-opendaylight.tar"}
    ]
    virt_utils.virt_customize(virt_ops, image)
    logging.info("OpenDaylight injected into {}".format(image))
