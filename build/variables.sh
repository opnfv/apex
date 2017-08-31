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
BUILD_UTILS="$(dirname ${BUILD_ROOT})/apex/build/build_utils.py"


rdo_images_uri=${RDO_IMAGES_URI:-http://artifacts.opnfv.org/apex/euphrates/rdo}

onos_release_uri=https://downloads.onosproject.org/release/
onos_release_file=onos-1.8.4.tar.gz
onos_jdk_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_pkg=package_ovs_rpm3.tar.gz
if [ -z ${GS_PATHNAME+x} ]; then
    GS_PATHNAME=/colorado
fi
dpdk_uri_base=http://artifacts.opnfv.org/ovsnfv/danube
dpdk_rpms=(
'ovs4opnfv-e8acab14-dpdk-16.11-5.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-devel-16.11-5.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-examples-16.11-5.el7.centos.x86_64.rpm'
'ovs4opnfv-e8acab14-dpdk-tools-16.11-5.el7.centos.x86_64.rpm'
)

kvmfornfv_uri_base="http://artifacts.opnfv.org/kvmfornfv/danube"
kvmfornfv_kernel_rpm="kvmfornfv-4bfeded9-apex-kernel-4.4.50_rt62_centos.x86_64.rpm"

calipso_uri_base="https://git.opnfv.org/calipso/plain/app/install"
calipso_script="calipso-installer.py"

netvpp_repo="https://github.com/openstack/networking-vpp"
netvpp_branch="master"
netvpp_commit=$(git ls-remote ${netvpp_repo} ${netvpp_branch} | awk '{print substr($1,1,7)}')
netvpp_pkg=python-networking-vpp-0.0.1-1.git${NETVPP_COMMIT}$(rpm -E %dist).noarch.rpm

gluon_rpm=gluon-0.0.1-1_20170302.noarch.rpm

fdio_pkgs=(
'http://artifacts.opnfv.org/apex/danube/fdio_common_rpms/vpp-17.04.1-3~ge3b7ad7~b72.x86_64.rpm'
'http://artifacts.opnfv.org/apex/danube/fdio_common_rpms/vpp-api-python-17.04.1-3~ge3b7ad7~b72.x86_64.rpm'
'http://artifacts.opnfv.org/apex/danube/fdio_common_rpms/vpp-lib-17.04.1-3~ge3b7ad7~b72.x86_64.rpm'
'http://artifacts.opnfv.org/apex/danube/fdio_common_rpms/vpp-plugins-17.04.1-3~ge3b7ad7~b72.x86_64.rpm'
)

honeycomb_pkg='http://artifacts.opnfv.org/apex/danube/fdio_common_rpms/honeycomb-1.17.04.1-2073.noarch.rpm'
