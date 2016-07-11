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
pushd images > /dev/null

################################################
#####    Adding SFC+OpenDaylight overcloud #####
################################################

#copy opendaylight overcloud full to odl-sfc
cp -f overcloud-full-opendaylight.qcow2 overcloud-full-opendaylight-sfc_build.qcow2

# upgrade ovs into ovs 2.5.90 with NSH function
if ! [[ -f openvswitch-2.5.90-1.el7.centos.x86_64.rpm  &&  -f openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm ]]; then
  curl -L -O ${onos_ovs_uri}/package_ovs_rpm.tar.gz
  tar -xzf package_ovs_rpm.tar.gz
fi

LIBGUESTFS_BACKEND=direct virt-customize --upload openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm:/root/ \
                                         --run-command "yum install -y /root/openvswitch-kmod-2.5.90-1.el7.centos.x86_64.rpm" \
                                         --upload openvswitch-2.5.90-1.el7.centos.x86_64.rpm:/root/ \
                                         --run-command "yum upgrade -y /root/openvswitch-2.5.90-1.el7.centos.x86_64.rpm" \
                                         -a overcloud-full-opendaylight-sfc_build.qcow2

mv overcloud-full-opendaylight-sfc_build.qcow2 overcloud-full-opendaylight-sfc.qcow2
popd > /dev/null
