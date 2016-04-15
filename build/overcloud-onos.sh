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

pushd images > /dev/null
cp -f overcloud-full.qcow2 overcloud-full-onos_build.qcow2

#######################################
#####    Adding ONOS to overcloud #####
#######################################

# get the onos files
rm -rf puppet-onos
git clone https://github.com/bobzhouHW/puppet-onos.git
populate_cache "$onos_release_uri/$onos_release_file"

# download jdk, onos and maven dependancy packages.
#for i in jdk-8u51-linux-x64.tar.gz onos-1.3.0.tar.gz repository.tar; do

tar --xform="s:puppet-onos/:onos/:" -czf puppet-onos.tar.gz puppet-onos

LIBGUESTFS_BACKEND=direct virt-customize --install "java-1.8.0-openjdk" \
                                         --upload puppet-onos.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-onos.tar.gz" \
                                         --upload cache/$onos_release_file:/opt \
                                         --run-command "cd /opt && tar xzf $onos_release_file" \
                                         -a overcloud-full-onos_build.qcow2

mv overcloud-full-onos_build.qcow2 overcloud-full-onos.qcow2
popd > /dev/null
