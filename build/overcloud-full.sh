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

dpdk_pkg_str=''
for package in ${dpdk_rpms[@]}; do
  curl -O "$dpdk_uri_base/$package"
  dpdk_pkg_str+=" --upload $package:/root/dpdk_rpms"
done

# remove openstack-neutron-openvswitch, ain't nobody need that in OPNFV
# enable connection tracking for protocal sctp
# upload dpdk rpms but do not install
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --run-command "mkdir /root/dpdk_rpms" \
    $dpdk_pkg_str \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
