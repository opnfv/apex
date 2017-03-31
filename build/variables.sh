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
QUAGGA_RPMS_DIR=${BUILD_DIR}/quagga_build_dir
CACHE_DIR="$(dirname ${BUILD_ROOT})/.cache"
CACHE_HISTORY=".cache_history"
PATCHES_DIR="${BUILD_ROOT}/patches"

# TODO: swap these back out when the CDN is ready, images.rdo project is the build host with very little bandwidth
#rdo_images_uri=${RDO_IMAGES_URI:-http://buildlogs.centos.org/centos/7/cloud/$(uname -p)/tripleo_images/ocata/delorean}
rdo_images_uri=${RDO_IMAGES_URI:-https://images.rdoproject.org/ocata/rdo_trunk/current-tripleo/stable/}
onos_release_uri=https://downloads.onosproject.org/nightly/
onos_release_file=onos-1.8.0-rc6.tar.gz
onos_jdk_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_pkg=package_ovs_rpm3.tar.gz
if [ -z ${GS_PATHNAME+x} ]; then
    GS_PATHNAME=/colorado
fi
dpdk_uri_base=http://artifacts.opnfv.org/ovsnfv
dpdk_rpms=(
'ovs4opnfv-e8acab14-dpdk-16.11-5.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-devel-16.11-5.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-examples-16.11-5.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-tools-16.11-5.el7.centos.x86_64.rpm'
)

kvmfornfv_uri_base="http://artifacts.opnfv.org/kvmfornfv"
kvmfornfv_kernel_rpm="kernel-4.4.6_rt14_1703030237nfv-1.x86_64.rpm"

netvpp_repo="https://github.com/openstack/networking-vpp"
netvpp_branch="master"
netvpp_commit=$(git ls-remote ${netvpp_repo} ${netvpp_branch} | awk '{print substr($1,1,7)}')
netvpp_pkg=python-networking-vpp-0.0.1-1.git${NETVPP_COMMIT}$(rpm -E %dist).noarch.rpm

gluon_rpm=gluon-0.0.1-1_20170302.noarch.rpm

fdio_l3_uri_base=http://artifacts.opnfv.org/apex/danube/fdio_l3_rpms
fdio_l3_pkgs=(
'vpp-17.04-rc0~399_g17a75cb~b2022.x86_64.rpm'
'vpp-api-python-17.04-rc0~399_g17a75cb~b2022.x86_64.rpm'
'vpp-lib-17.04-rc0~399_g17a75cb~b2022.x86_64.rpm'
'vpp-plugins-17.04-rc0~399_g17a75cb~b2022.x86_64.rpm'
'honeycomb-1.17.04-2503.noarch.rpm'
)

fdio_l2_uri_base=http://artifacts.opnfv.org/apex/danube/fdio_l2_rpms
fdio_l2_pkgs=(
'vpp-17.04-rc0~300_gdef19da~b1923.x86_64.rpm'
'vpp-api-python-17.04-rc0~300_gdef19da~b1923.x86_64.rpm'
'vpp-lib-17.04-rc0~300_gdef19da~b1923.x86_64.rpm'
'vpp-plugins-17.04-rc0~300_gdef19da~b1923.x86_64.rpm'
)

fdio_nosdn_uri_base=http://artifacts.opnfv.org/apex/danube/fdio_nosdn_rpms
fdio_nosdn_pkgs=(
'vpp-17.04-rc0~476_geaabe07~b2100.x86_64.rpm'
'vpp-api-python-17.04-rc0~476_geaabe07~b2100.x86_64.rpm'
'vpp-lib-17.04-rc0~476_geaabe07~b2100.x86_64.rpm'
'vpp-plugins-17.04-rc0~476_geaabe07~b2100.x86_64.rpm'
)
