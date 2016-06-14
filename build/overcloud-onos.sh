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
populate_cache "$onos_artifacts_uri/jdk-8u51-linux-x64.tar.gz"

#Those files can be store in local cache for saving download time
pushd puppet-onos/files > /dev/null
cp $CACHE_DIR/$onos_release_file ./onos-1.6.0.tar.gz
cp $CACHE_DIR/jdk-8u51-linux-x64.tar.gz ./
curl -O "$onos_artifacts_uri"repository.tar
popd > /dev/null 

tar --xform="s:puppet-onos/:onos/:" -czf puppet-onos.tar.gz puppet-onos

LIBGUESTFS_BACKEND=direct virt-customize --install "java-1.8.0-openjdk" \
                                         --upload puppet-onos.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-onos.tar.gz" \
                                         -a overcloud-full-onos_build.qcow2

#Those files can be store in local cache for saving download time
curl -O "$onos_artifacts_uri"package_ovs_rpm.tar.gz
tar -xzf package_ovs_rpm.tar.gz
LIBGUESTFS_BACKEND=direct virt-customize --upload openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm:/root/ \
                                         --run-command "rpm -i /root/openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm" \
                                         --upload openvswitch-2.5.90-1.el7.centos.x86_64.rpm:/root/ \
                                         --run-command "yum upgrade -y /root/openvswitch-2.5.90-1.el7.centos.x86_64.rpm" \
                                         -a overcloud-full-onos_build.qcow2



mv overcloud-full-onos_build.qcow2 overcloud-full-onos.qcow2
popd > /dev/null
