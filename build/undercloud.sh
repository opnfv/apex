#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -xe
source ./cache.sh
source ./variables.sh
source ./functions.sh

populate_cache "$rdo_images_uri/undercloud.qcow2"
if [ ! -d "$BUILD_DIR" ]; then mkdir ${BUILD_DIR}; fi
cp -f ${CACHE_DIR}/undercloud.qcow2 ${BUILD_DIR}/undercloud_build.qcow2

pushd ${BUILD_DIR} > /dev/null

# prep opnfv-tht for undercloud
clone_fork opnfv-tht
pushd opnfv-tht > /dev/null
git archive --format=tar.gz --prefix=openstack-tripleo-heat-templates/ HEAD > ${BUILD_DIR}/opnfv-tht.tar.gz
popd > /dev/null

# inject rt_kvm kernel rpm name into the enable file
sed -i "s/kvmfornfv_kernel.rpm/$kvmfornfv_kernel_rpm/" ${BUILD_ROOT}/enable_rt_kvm.yaml

# installing forked opnfv-tht
# enabling ceph OSDs to live on the controller
# OpenWSMan package update supports the AMT Ironic driver for the TealBox
# seeding configuration files specific to OPNFV
# add congress client
# add congress password to python-tripleoclient
# add tacker password to tripleo-common
# upload tacker repo and install the client package
# Add performance image scripts
# hack for disabling undercloud package update
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "sed -i 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config" \
    --run-command "sed -i 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config" \
    --upload ${BUILD_DIR}/opnfv-tht.tar.gz:/usr/share \
    --install "openstack-utils" \
    --install "ceph-common" \
    --run-command "cd /usr/share && rm -rf openstack-tripleo-heat-templates && tar xzf opnfv-tht.tar.gz" \
    --run-command "sed -i '/ControllerEnableCephStorage/c\\  ControllerEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "sed -i '/ComputeEnableCephStorage/c\\  ComputeEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "curl -f http://download.opensuse.org/repositories/Openwsman/CentOS_CentOS-7/Openwsman.repo > /etc/yum.repos.d/wsman.repo" \
    --run-command "yum update -y openwsman*" \
    --run-command "cp /usr/share/instack-undercloud/undercloud.conf.sample /home/stack/undercloud.conf && chown stack:stack /home/stack/undercloud.conf" \
    --upload ${BUILD_ROOT}/opnfv-environment.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/first-boot.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/kvm4nfv-1st-boot.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/enable_rt_kvm.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/ovs-dpdk-preconfig.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/csit-environment.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/virtual-environment.yaml:/home/stack/ \
    --install "python2-congressclient" \
    --run-command "sed -i '/SwiftPassword/a\    \x27TackerPassword\x27,' /usr/lib/python2.7/site-packages/tripleo_common/constants.py" \
    --run-command "sed -i '/CinderPassword/a\    \x27CongressPassword\x27,' /usr/lib/python2.7/site-packages/tripleo_common/constants.py" \
    --upload ${BUILD_DIR}/noarch/$tackerclient_pkg:/root/ \
    --install /root/$tackerclient_pkg \
    --install "python2-aodhclient" \
    --install "openstack-heat-engine" \
    --install "openstack-heat-api-cfn" \
    --install "openstack-heat-api" \
    --upload ${BUILD_ROOT}/patches/0001-Removes-doing-yum-update.patch:/usr/lib/python2.7/site-packages/ \
    --run-command "cd /usr/lib/python2.7/site-packages/ && patch -p1 < 0001-Removes-doing-yum-update.patch" \
    --root-password password:stack \
    -a undercloud_build.qcow2

mv -f undercloud_build.qcow2 undercloud.qcow2
popd > /dev/null
