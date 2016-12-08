#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -e
source ./cache.sh
source ./variables.sh

pushd ${BUILD_DIR} > /dev/null
cp -f overcloud-full.qcow2 overcloud-full-onos_build.qcow2

#######################################
#####    Adding ONOS to overcloud #####
#######################################

# get the onos files
rm -rf puppet-onos
populate_cache "$onos_release_uri/$onos_release_file" "$(curl https://downloads.onosproject.org/nightly/ | grep $onos_release_file | grep -o -e '[0-9a-f]\{32\}')"
populate_cache "$onos_jdk_uri/jdk-8u51-linux-x64.tar.gz"

LIBGUESTFS_BACKEND=direct virt-customize --upload ${CACHE_DIR}/${onos_release_file}:/opt/ \
                                         --run-command "mkdir /opt/onos && cd /opt/ && tar -xzf $onos_release_file -C /opt/onos --strip-components=1" \
                                         -a overcloud-full-onos_build.qcow2

#Those files can be store in local cache for saving download time
git clone https://github.com/bobzhouHW/puppet-onos.git
tar --xform="s:puppet-onos/:onos/:" -czf puppet-onos.tar.gz puppet-onos

LIBGUESTFS_BACKEND=direct virt-customize --upload ${CACHE_DIR}/jdk-8u51-linux-x64.tar.gz:/opt/ \
                                         --upload ${BUILD_DIR}/puppet-onos/files/install_jdk8.tar:/opt/ \
                                         --run-command "cd /opt/ && tar -xf install_jdk8.tar && sh /opt/install_jdk8/install_jdk8.sh" \
                                         --upload ${BUILD_DIR}/puppet-onos.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-onos.tar.gz" \
                                         -a overcloud-full-onos_build.qcow2

mv overcloud-full-onos_build.qcow2 overcloud-full-onos.qcow2
popd > /dev/null
