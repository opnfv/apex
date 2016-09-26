#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

rdo_images_uri=http://artifacts.opnfv.org/apex/colorado
onos_release_uri=https://downloads.onosproject.org/nightly/
onos_release_file=onos-1.6.0-rc2.tar.gz
onos_jdk_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_uri=http://artifacts.opnfv.org/apex/colorado
onos_ovs_pkg=package_ovs_rpm3.tar.gz
doctor_driver=https://raw.githubusercontent.com/openstack/congress/master/congress/datasources/doctor_driver.py
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

fdio_uri_base=http://artifacts.opnfv.org/apex/colorado
fdio_pkgs=(
'vpp-16.09-2~g019886e~b1072.x86_64.rpm'
'vpp-devel-16.09-2~g019886e~b1072.x86_64.rpm'
'vpp-lib-16.09-2~g019886e~b1072.x86_64.rpm'
'vpp-python-api-16.09-3~gdc30144_dirty.x86_64.rpm'
)
honeycomb_pkg='honeycomb-1.16.9-FINAL.noarch.rpm'


ovs_rpm_name=openvswitch-2.5.90-1.el7.centos.x86_64.rpm
ovs_kmod_rpm_name=openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm

virt_uri_base=https://people.redhat.com/~rjones/libguestfs-RHEL-7.3-preview
libguestfs_pkg='libguestfs-1.32.7-3.el7.x86_64.rpm'
virt_pkgs=(
'libguestfs-tools-1.32.7-3.el7.noarch.rpm'
'libguestfs-tools-c-1.32.7-3.el7.x86_64.rpm'
'supermin-5.1.16-4.el7.x86_64.rpm'
'supermin5-5.1.16-4.el7.x86_64.rpm'
'supermin-helper-5.1.16-4.el7.x86_64.rpm'
'perl-Sys-Guestfs-1.32.7-3.el7.x86_64.rpm'
'python-libguestfs-1.32.7-3.el7.x86_64.rpm'
)
