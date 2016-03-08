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

cp -f overcloud-full.qcow2 overcloud-full-opendaylight_build.qcow2

###############################################
#####    Adding OpenDaylight to overcloud #####
###############################################

cat > /tmp/opendaylight.repo << EOF
[opendaylight-41-release]
name=CentOS CBS OpenDaylight Beryllium SR1 repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-41-release/\$basearch/os/
enabled=1
gpgcheck=0
EOF

# install ODL packages
# patch puppet-neutron: ODL Bug, Url check reports ODL is up but it's not quite up
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload /tmp/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --install opendaylight,python-networking-odl \
    --install https://github.com/michaeltchapman/networking_rpm/raw/master/openstack-neutron-bgpvpn-2015.2-1.el7.centos.noarch.rpm \
    -a overcloud-full-opendaylight_build.qcow2

# install Jolokia for ODL HA
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "wget https://github.com/rhuss/jolokia/releases/download/v1.3.3/jolokia-1.3.3-bin.tar.gz -O /tmp/jolokia-1.3.3-bin.tar.gz" \
    --run-command "tar -xvf /tmp/jolokia-1.3.3-bin.tar.gz -C /opt/opendaylight/system/org" \
    -a overcloud-full-opendaylight_build.qcow2

## WORK AROUND
## when OpenDaylight lands in upstream RDO manager this can be removed

# upload the opendaylight puppet module
rm -rf puppet-opendaylight
git clone -b opnfv_integration https://github.com/dfarrell07/puppet-opendaylight
pushd puppet-opendaylight > /dev/null
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ../puppet-opendaylight.tar.gz
popd > /dev/null
LIBGUESTFS_BACKEND=direct virt-customize --upload puppet-opendaylight.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-opendaylight.tar.gz" \
                                         -a overcloud-full-opendaylight_build.qcow2

mv overcloud-full-opendaylight_build.qcow2 overcloud-full-opendaylight.qcow2
popd > /dev/null
