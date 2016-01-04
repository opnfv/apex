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

populate_cache "$rdo_images_uri/overcloud-full.tar"

if [ ! -d images/ ]; then mkdir images; fi
tar -xf cache/overcloud-full.tar -C images/
mv -f images/overcloud-full.qcow2 images/overcloud-full_build.qcow2

##########################################################
#####  Prep initial overcloud image with common deps #####
##########################################################

pushd images > /dev/null
# Update puppet-aodh it's old
rm -rf aodh
git clone https://github.com/openstack/puppet-aodh aodh
pushd aodh > /dev/null
git checkout stable/liberty
popd > /dev/null
tar -czf puppet-aodh.tar.gz aodh

# grab latest puppet-neutron module
rm -rf puppet-neutron
git clone -b stable/liberty https://github.com/openstack/puppet-neutron.git
pushd puppet-neutron
git archive --format=tar.gz --prefix=neutron/ HEAD > ../puppet-neutron.tar.gz
popd


# Add epel to install ceph
# update aodh
# puppet-neutron-force-metadata.patch
# puppet-cinder-quota-fix
#aodh-puppet-tripleo
AODH_PKG="openstack-aodh-api,openstack-aodh-common,openstack-aodh-compat,openstack-aodh-evaluator,openstack-aodh-expirer"
AODH_PKG+=",openstack-aodh-listener,openstack-aodh-notifier"
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload puppet-aodh.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && rm -rf aodh && tar xzf puppet-aodh.tar.gz" \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    --install "$AODH_PKG,ceph" \
    --run-command "rm -rf /etc/puppet/modules/neutron" \
    --upload puppet-neutron.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-neutron.tar.gz" \
    --upload ../puppet-cinder-quota-fix.patch:/tmp \
    --run-command "cd /etc/puppet/modules/cinder && patch -Np1 < /tmp/puppet-cinder-quota-fix.patch" \
    --upload ../aodh-puppet-tripleo.patch:/tmp \
    --run-command "cd /etc/puppet/modules/tripleo && patch -Np1 < /tmp/aodh-puppet-tripleo.patch" \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
