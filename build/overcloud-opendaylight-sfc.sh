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
source ./variables.sh
pushd images > /dev/null

################################################
#####    Adding SFC+OpenDaylight overcloud #####
################################################

#copy opendaylight overcloud full to odl-sfc
cp -f overcloud-full-opendaylight.qcow2 overcloud-full-opendaylight-sfc_build.qcow2

# upgrade ovs into ovs 2.5.90 with NSH function
if ! [[ -f "$ovs_rpm_name"  &&  -f "$ovs_kmod_rpm_name" ]]; then
  curl -L -O ${onos_ovs_uri}/${onos_ovs_pkg}
  tar -xzf ${onos_ovs_pkg}
fi

LIBGUESTFS_BACKEND=direct virt-customize --upload ${ovs_kmod_rpm_name}:/root/ \
                                         --run-command "yum install -y /root/${ovs_kmod_rpm_name}" \
                                         --upload ${ovs_rpm_name}:/root/ \
                                         --run-command "yum upgrade -y /root/${ovs_rpm_name}" \
                                         -a overcloud-full-opendaylight-sfc_build.qcow2

mv overcloud-full-opendaylight-sfc_build.qcow2 overcloud-full-opendaylight-sfc.qcow2
popd > /dev/null
