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

cache_file "$rdo_images_uri/undercloud.qcow2"
if [ ! -d images ]; then mkdir images/; fi
cp -f cache/undercloud.qcow2 images/

#Adding OpenStack packages to undercloud
pushd images > /dev/null

LIBGUESTFS_BACKEND=direct virt-customize --install yum-priorities -a undercloud.qcow2
PACKAGES="qemu-kvm-common,qemu-kvm,libvirt-daemon-kvm,libguestfs,python-libguestfs,openstack-nova-compute"
PACKAGES+=",openstack-swift,openstack-ceilometer-api,openstack-neutron-ml2,openstack-ceilometer-alarm"
PACKAGES+=",openstack-nova-conductor,openstack-ironic-inspector,openstack-ironic-api,python-openvswitch"
PACKAGES+=",openstack-glance,python-glance,python-troveclient,openstack-puppet-modules"
PACKAGES+=",openstack-neutron,openstack-neutron-openvswitch,openstack-nova-scheduler,openstack-keystone,openstack-swift-account"
PACKAGES+=",openstack-swift-container,openstack-swift-object,openstack-swift-plugin-swift3,openstack-swift-proxy"
PACKAGES+=",openstack-nova-api,openstack-nova-cert,openstack-heat-api-cfn,openstack-heat-api,"
PACKAGES+=",openstack-ceilometer-central,openstack-ceilometer-polling,openstack-ceilometer-collector,"
PACKAGES+=",openstack-heat-api-cloudwatch,openstack-heat-engine,openstack-heat-common,openstack-ceilometer-notification"
PACKAGES+=",hiera,puppet,memcached,keepalived,mariadb,mariadb-server,rabbitmq-server,python-pbr,python-proliantutils"
PACKAGES+=",ceph-common"

# install the packages above and enabling ceph to live on the controller
LIBGUESTFS_BACKEND=direct virt-customize --install $PACKAGES \
    --run-command "sed -i '/ControllerEnableCephStorage/c\\  ControllerEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller_pacemaker.pp" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller.pp" \
    -a undercloud.qcow2

# Patch in OpenDaylight installation and configuration
LIBGUESTFS_BACKEND=direct virt-customize --upload ../opnfv-tripleo-heat-templates.patch:/tmp \
                                         --run-command "cd /usr/share/openstack-tripleo-heat-templates/ && patch -Np1 < /tmp/opnfv-tripleo-heat-templates.patch" \
                                         -a undercloud.qcow2

# adds tripleoclient aodh workaround
# for keystone
LIBGUESTFS_BACKEND=direct virt-customize --upload ../aodh-tripleoclient.patch:/tmp \
                                         --run-command "cd /usr/lib/python2.7/site-packages/tripleoclient && patch -Np1 < /tmp/aodh-tripleoclient.patch" \
                                         --upload ../aodh-os-cloud-config.patch:/tmp \
                                         --run-command "cd /usr/lib/python2.7/site-packages/os_cloud_config && patch -Np1 < /tmp/aodh-os-cloud-config.patch" \
                                         -a undercloud.qcow2
popd > /dev/null
