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
cache_file "$rdo_images_uri/overcloud-full.tar"

if [ ! -d images/ ]; then mkdir images; fi
tar -xf cache/overcloud-full.tar -C images/

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

# Add epel to install ceph
# update aodh
# remove openstack-neutron-openvswitch, ain't nobody need that in OPNFV
AODH_PKG="openstack-aodh-api,openstack-aodh-common,openstack-aodh-compat,openstack-aodh-evaluator,openstack-aodh-expirer"
AODH_PKG+=",openstack-aodh-listener,openstack-aodh-notifier"
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload puppet-aodh.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && rm -rf aodh && tar xzf puppet-aodh.tar.gz" \
    --run-command "yum remove -y openstack-neutron-openvswitch" \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    --install "$AODH_PKG,ceph" \
    -a overcloud-full.qcow2
popd > /dev/null
