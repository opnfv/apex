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

cp overcloud-full.qcow2 overcloud-full-opendaylight.qcow2

###############################################
#####    Adding OpenDaylight to overcloud #####
###############################################

cat > /tmp/opendaylight.repo << EOF
[opendaylight]
name=OpenDaylight \$releasever - \$basearch
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-40-release/\$basearch/os/
enabled=1
gpgcheck=0
EOF

# install ODL packages
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload /tmp/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --install opendaylight,python-networking-odl \
    --install https://github.com/michaeltchapman/networking_rpm/raw/master/openstack-neutron-bgpvpn-2015.2-1.el7.centos.noarch.rpm \
    -a overcloud-full-opendaylight.qcow2

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
                                         --upload ../opendaylight-puppet-neutron.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/neutron && patch -Np1 < /tmp/opendaylight-puppet-neutron.patch" \
                                         -a overcloud-full-opendaylight.qcow2

LIBGUESTFS_BACKEND=direct virt-customize --upload ../puppet-neutron-force-metadata.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/neutron && patch -Np1 < /tmp/puppet-neutron-force-metadata.patch" \
                                         -a overcloud-full-opendaylight.qcow2

LIBGUESTFS_BACKEND=direct virt-customize --upload ../puppet-cinder-quota-fix.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/cinder && patch -Np1 < /tmp/puppet-cinder-quota-fix.patch" \
                                         -a overcloud-full-opendaylight.qcow2

LIBGUESTFS_BACKEND=direct virt-customize --upload ../aodh-puppet-tripleo.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/tripleo && patch -Np1 < /tmp/aodh-puppet-tripleo.patch" \
                                         -a overcloud-full-opendaylight.qcow2

popd > /dev/null
