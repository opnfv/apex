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

# remove openstack-neutron-openvswitch, ain't nobody need that in OPNFV
# enable connection tracking for protocal sctp
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    -a overcloud-full_build.qcow2

############################################
#####  Add Kernel Parameter Mod Script #####
############################################

LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ../setkernelparam.sh:/root \
    -a overcloud-full_build.qcow2

###############################
#####  Add OVS DPDK Tools #####
###############################
# michchap: I don't know if these will be needed, the puppet is doing a source build+install so may
#           be counterproductive

rm -rf networking-ovs-dpdk
git clone -b stable/mitaka https://github.com/openstack/networking-ovs-dpdk
pushd networking-ovs-dpdk > /dev/null
git archive --format=tar.gz --prefix=networking-ovs-dpdk/ HEAD > ../networking-ovs-dpdk.tar.gz
popd > /dev/null
LIBGUESTFS_BACKEND=direct virt-customize --run-command "mkdir -p /usr/share/apex-dpdk" \
                                         --upload networking-ovs-dpdk.tar.gz:/usr/share/apex-dpdk \
                                         --run-command "cd /usr/share/apex-dpdk && tar xzf networking-ovs-dpdk.tar.gz" \
                                         --run-command "ln -s /usr/share/apex-dpdk/networking-ovs-dpdk/puppet/ovsdpdk /etc/puppet/modules/ovsdpdk" \
                                         -a overcloud-full_build.qcow2

# Upload the ovs-dpdk rpm, but don't install it since it will
# replace OVS. The install must be done at deploy time when we
# know the option is set
guestfs_string=''

for package in ${ovsdpdk_rpms[@]} $ovsdpdk_ovs_rpm; do
  rm -rf $package
  curl -O "$ovsdpdk_uri_base/$package"
  guestfs_string+=" --upload $package:/usr/share/apex-dpdk"
done

guestfs_string+=" -a overcloud-full_build.qcow2"

LIBGUESTFS_BACKEND=direct virt-customize $guestfs_string

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
