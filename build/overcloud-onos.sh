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

# upgrade ovs into ovs 2.5.90 with NSH function
curl -O "$onos_artifacts_uri"package_ovs_rpm.tar.gz
tar -xzf package_ovs_rpm.tar.gz
ovs_kmod=$(ls | grep openvswitch-kmod-[0-9])
ovs=$(ls | grep openvswitch-[0-9])
LIBGUESTFS_BACKEND=direct virt-customize --upload $ovs_kmod:/root/ \
                                         --run-command "yum install -y /root/$ovs_kmod" \
                                         --upload $ovs:/root/ \
                                         --run-command "yum upgrade -y /root/$ovs" \
                                         -a overcloud-full-onos_build.qcow2

# get the onos files
rm -rf puppet-onos
populate_cache "$onos_release_uri/$onos_release_file"
populate_cache "$onos_artifacts_uri/jdk-8u51-linux-x64.tar.gz"

LIBGUESTFS_BACKEND=direct virt-customize --upload $CACHE_DIR/$onos_release_file:/opt/ \
                                         --run-command "mkdir /opt/onos && cd /opt/ && tar -xzf $onos_release_file -C /opt/onos --strip-components=1" \
                                         -a overcloud-full-onos_build.qcow2

#Those files can be store in local cache for saving download time
git clone https://github.com/bobzhouHW/puppet-onos.git
tar --xform="s:puppet-onos/:onos/:" -czf puppet-onos.tar.gz puppet-onos

LIBGUESTFS_BACKEND=direct virt-customize --upload $CACHE_DIR/jdk-8u51-linux-x64.tar.gz:/opt/ \
                                         --upload puppet-onos/files/install_jdk8.tar:/opt/ \
                                         --run-command "cd /opt/ && tar -xf install_jdk8.tar && sh /opt/install_jdk8/install_jdk8.sh" \
                                         --upload puppet-onos.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-onos.tar.gz" \
                                         -a overcloud-full-onos_build.qcow2

mv overcloud-full-onos_build.qcow2 overcloud-full-onos.qcow2
popd > /dev/null
