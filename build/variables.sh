#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

rdo_images_uri=https://ci.centos.org/artifacts/rdo/images/mitaka/delorean/stable/
onos_release_uri=https://downloads.onosproject.org/nightly/
onos_release_file=onos-1.6.0-rc2.tar.gz
onos_artifacts_uri=http://205.177.226.237:9999/onosfw/
openstack_congress=https://radez.fedorapeople.org/openstack-congress-2016.1-1.fc24.noarch.rpm
doctor_driver=https://raw.githubusercontent.com/muroi/congress/doctor-poc/congress/datasources/doctor_driver.py

dpdk_uri_base=http://artifacts.opnfv.org/ovsnfv
dpdk_rpms=(
'ovs4opnfv-dpdk-16.04.0-2.el7.centos.x86_64.rpm'
'ovs4opnfv-dpdk-devel-16.04.0-2.el7.centos.x86_64.rpm'
'ovs4opnfv-dpdk-examples-16.04.0-2.el7.centos.x86_64.rpm'
'ovs4opnfv-dpdk-tools-16.04.0-2.el7.centos.x86_64.rpm'
'ovs4opnfv-openvswitch-2.5.90-0.12060.git46ed1382.1.el7.centos.x86_64.rpm'
)
