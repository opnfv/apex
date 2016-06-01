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
onos_release_uri=https://dl.dropboxusercontent.com/u/7079970/
onos_release_file=onos-1.5.0.tar.gz

# OVS DPDK
ovsdpdk_uri_base=http://artifacts.opnfv.org/ovsnfv
ovsdpdk_ovs_rpm=ovs4opnfv-openvswitch-2.5.90-0.12060.git46ed1382.1.el7.centos.x86_64.rpm
ovsdpdk_rpms=(
'ovs4opnfv-dpdk-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-dpdk-devel-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-dpdk-examples-16.04.0-1.el7.centos.x86_64.rpm'
'ovs4opnfv-dpdk-tools-16.04.0-1.el7.centos.x86_64.rpm'
)
