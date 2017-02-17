#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

BUILD_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_DIR="$(dirname ${BUILD_ROOT})/.build"
CACHE_DIR="$(dirname ${BUILD_ROOT})/.cache"
CACHE_HISTORY=".cache_history"

rdo_images_uri=http://buildlogs.centos.org/centos/7/cloud/x86_64/tripleo_images/newton/delorean
onos_release_uri=https://downloads.onosproject.org/nightly/
onos_release_file=onos-1.8.0-rc6.tar.gz
onos_jdk_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_pkg=package_ovs_rpm3.tar.gz
if [ -z ${GS_PATHNAME+x} ]; then
    GS_PATHNAME=/colorado
fi
dpdk_uri_base=http://artifacts.opnfv.org/ovsnfv$GS_PATHNAME
dpdk_rpms=(
'ovs4opnfv-e8acab14-dpdk-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-devel-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-examples-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-tools-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-openvswitch-2.5.90-0.12032.gitc61e93d6.1.el7.centos.x86_64.rpm'
)

tacker_repo="http://github.com/openstack/tacker"
tacker_branch="stable/newton"
tacker_commit=$(git ls-remote ${tacker_repo} ${tacker_branch} | awk '{print substr($1,1,7)}')
tacker_pkg=openstack-tacker-2016.2-1.git${tacker_commit}.noarch.rpm

tackerclient_repo="http://github.com/openstack/python-tackerclient"
tackerclient_branch="stable/newton"
tackerclient_commit=$(git ls-remote ${tackerclient_repo} ${tackerclient_branch} | awk '{print substr($1,1,7)}')
tackerclient_pkg=python-tackerclient-2016.2-1.git${tackerclient_commit}.noarch.rpm

congress_repo="http://github.com/openstack/congress"
congress_branch="stable/newton"
congress_commit=$(git ls-remote ${congress_repo} ${congress_branch} | awk '{print substr($1,1,7)}')
congress_pkg=openstack-congress-2016.2-1.git${congress_commit}$(rpm -E %dist).noarch.rpm

netvpp_repo="https://github.com/openstack/networking-vpp"
netvpp_branch="master"
netvpp_commit=$(git ls-remote ${netvpp_repo} ${netvpp_branch} | awk '{print substr($1,1,7)}')
netvpp_pkg=python-networking-vpp-0.0.1-1.git${NETVPP_COMMIT}$(rpm -E %dist).noarch.rpm
