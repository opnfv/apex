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
cp overcloud-full.qcow2 overcloud-full-onos.qcow2

#######################################
#####    Adding ONOS to overcloud #####
#######################################

# upload the onos puppet module
rm -rf puppet-onos
git clone https://github.com/bobzhouHW/puppet-onos.git
pushd puppet-onos > /dev/null

# download jdk, onos and maven dependancy packages.
pushd files
for i in jdk-8u51-linux-x64.tar.gz onos-1.3.0.tar.gz repository.tar; do
    cache_file ${onos_artifacts_uri}/$i
    get_cached_file $i
done
popd > /dev/null

popd > /dev/null
tar --xform="s:puppet-onos/:onos/:" -czf puppet-onos.tar.gz puppet-onos

LIBGUESTFS_BACKEND=direct virt-customize --upload puppet-onos.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-onos.tar.gz" -a overcloud-full-opendaylight.qcow2
popd > /dev/null
