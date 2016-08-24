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
onos_jdk_uri=https://www.dropbox.com/s/qyujpib8zyhzeev
onos_ovs_uri=https://www.dropbox.com/s/ojknqcozb2w6z3l
onos_ovs_pkg=package_ovs_rpm3.tar.gz
doctor_driver=https://raw.githubusercontent.com/openstack/congress/master/congress/datasources/doctor_driver.py

dpdk_uri_base=http://artifacts.opnfv.org/ovsnfv
dpdk_rpms=(
'ovs4opnfv-55ef39e7-dpdk-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-55ef39e7-dpdk-devel-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-55ef39e7-dpdk-examples-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-55ef39e7-dpdk-tools-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-55ef39e7-openvswitch-2.5.90-0.12032.gitc61e93d6.1.el7.centos.x86_64.rpm'
)

ovs_rpm_name=openvswitch-2.5.90-1.el7.centos.x86_64.rpm
ovs_kmod_rpm_name=openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm
