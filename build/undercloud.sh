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

populate_cache "$rdo_images_uri/undercloud.qcow2"
if [ ! -d "$BUILD_DIR" ]; then mkdir ${BUILD_DIR}; fi
cp -f ${CACHE_DIR}/undercloud.qcow2 ${BUILD_DIR}/undercloud_build.qcow2

pushd ${BUILD_DIR} > /dev/null

# prep apex-tht for undercloud
python3 -B $BUILD_UTILS clone-fork -r apex-tripleo-heat-templates -b stable/euphrates
pushd apex-tripleo-heat-templates > /dev/null
git archive --format=tar.gz --prefix=openstack-tripleo-heat-templates/ HEAD > ${BUILD_DIR}/apex-tripleo-heat-templates.tar.gz
popd > /dev/null

# inject rt_kvm kernel rpm name into the enable file
sed "s/kvmfornfv_kernel.rpm/$kvmfornfv_kernel_rpm/" ${BUILD_ROOT}/enable_rt_kvm.yaml | tee ${BUILD_DIR}/enable_rt_kvm.yaml

# grab latest calipso
populate_cache $calipso_uri_base/$calipso_script

# Turn off GSSAPI Auth in sshd
# installing forked apex-tht
# enabling ceph OSDs to live on the controller
# seeding configuration files specific to OPNFV
# Add performance image scripts
# Override delorean repo with current tripleo (REMOVE when upgrading to Pike)
LIBGUESTFS_BACKEND=direct $VIRT_CUSTOMIZE \
    --run-command "sed -i 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config" \
    --run-command "sed -i 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config" \
    --upload ${BUILD_DIR}/apex-tripleo-heat-templates.tar.gz:/usr/share \
    --install "openstack-utils" \
    --install "ceph-common" \
    --install "http://mirror.centos.org/centos/7/cloud/x86_64/openstack-ocata/python2-networking-sfc-4.0.0-1.el7.noarch.rpm" \
    --run-command "cd /etc/yum.repos.d && curl -O https://trunk.rdoproject.org/centos7-ocata/current-tripleo/delorean.repo" \
    --install openstack-nova-compute \
    --install epel-release \
    --install python34,python34-pip \
    --install openstack-ironic-inspector,subunit-filters,docker-distribution,openstack-tripleo-validations \
    --run-command "cd /usr/share && rm -rf openstack-tripleo-heat-templates && tar xzf apex-tripleo-heat-templates.tar.gz" \
    --run-command "sed -i '/ControllerEnableCephStorage/c\\  ControllerEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "sed -i '/ComputeEnableCephStorage/c\\  ComputeEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "cp /usr/share/instack-undercloud/undercloud.conf.sample /home/stack/undercloud.conf && chown stack:stack /home/stack/undercloud.conf" \
    --upload ${BUILD_ROOT}/opnfv-environment.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/first-boot.yaml:/home/stack/ \
    --upload ${BUILD_DIR}/enable_rt_kvm.yaml:/usr/share/openstack-tripleo-heat-templates/environments/ \
    --upload ${BUILD_ROOT}/ovs-dpdk-preconfig.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/csit-environment.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/virtual-environment.yaml:/home/stack/ \
    --upload ${BUILD_ROOT}/baremetal-environment.yaml:/home/stack/ \
    --uninstall "libvirt-client" \
    --upload ${CACHE_DIR}/${calipso_script}:/root/ \
    --install "libguestfs-tools" \
    --install "python-tackerclient" \
    --upload ${BUILD_ROOT}/patches/tacker-client-fix-symmetrical.patch:/usr/lib/python2.7/site-packages/ \
    --run-command "cd usr/lib/python2.7/site-packages/ && patch -p1 < tacker-client-fix-symmetrical.patch" \
    --run-command "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo" \
    --install yum-utils,lvm2,device-mapper-persistent-data \
    -a undercloud_build.qcow2

mv -f undercloud_build.qcow2 undercloud.qcow2
popd > /dev/null
