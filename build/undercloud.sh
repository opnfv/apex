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

populate_cache "$rdo_images_uri/undercloud.qcow2"
if [ ! -d images ]; then mkdir images/; fi
cp -f cache/undercloud.qcow2 images/

#Adding OpenStack packages to undercloud
pushd images > /dev/null

# install the packages above and enabling ceph to live on the controller
# OpenWSMan package update supports the AMT Ironic driver for the TealBox
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "sed -i '/ControllerEnableCephStorage/c\\  ControllerEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller_pacemaker.pp" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller.pp" \
    --run-command "curl http://download.opensuse.org/repositories/Openwsman/CentOS_CentOS-7/Openwsman.repo > /etc/yum.repos.d/wsman.repo" \
    --run-command "yum update -y openwsman*" \
    --run-command "cp /usr/share/instack-undercloud/undercloud.conf.sample /home/stack/undercloud.conf && chown stack:stack /home/stack/undercloud.conf" \
    -a undercloud.qcow2

# Patch in OpenDaylight installation and configuration
#LIBGUESTFS_BACKEND=direct virt-customize --upload ../opnfv-tripleo-heat-templates.patch:/tmp \
#                                         --run-command "cd /usr/share/openstack-tripleo-heat-templates/ && patch -Np1 < /tmp/opnfv-tripleo-heat-templates.patch" \
#                                         -a undercloud.qcow2
popd > /dev/null

# Copy opnfv-environment file to undercloud
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload /var/opt/opnfv/opnfv-environment.yaml:/home/stack/ \
    -a undercloud.qcow2
