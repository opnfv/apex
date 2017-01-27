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

pushd ${BUILD_DIR} > /dev/null

cp -f overcloud-full.qcow2 overcloud-full-opendaylight_build.qcow2

###############################################
#####    Adding OpenDaylight to overcloud #####
###############################################

# tar up fdio networking-odl
rm -rf fds
git clone https://gerrit.opnfv.org/gerrit/fds
pushd fds > /dev/null
tar -czvf ${BUILD_DIR}/networking-odl.tar.gz networking-odl
popd > /dev/null

# Beryllium Repo
cat > ${BUILD_DIR}/opendaylight.repo << EOF
[opendaylight-4-release]
name=CentOS CBS OpenDaylight Beryllium repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-4-release/\$basearch/os/
enabled=1
gpgcheck=0
EOF

# Boron Repo
cat > ${BUILD_DIR}/opendaylight_boron.repo << EOF
[opendaylight-5-release]
name=CentOS CBS OpenDaylight Boron repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-5-testing/\$basearch/os/
enabled=1
gpgcheck=0
EOF

# Master Repo
cat > ${BUILD_DIR}/opendaylight_master.repo << EOF
[opendaylight-6-release]
name=CentOS CBS OpenDaylight Carbon repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-6-testing/\$basearch/os/
enabled=1
gpgcheck=0
EOF

# OpenDaylight Puppet Module
rm -rf puppet-opendaylight
git clone -b master https://github.com/dfarrell07/puppet-opendaylight
pushd puppet-opendaylight > /dev/null
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ${BUILD_DIR}/puppet-opendaylight.tar.gz
popd > /dev/null

# install ODL packages
# install Jolokia for ODL HA
# Patch in OPNFV custom puppet-tripleO
# install Honeycomb
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ${BUILD_DIR}/networking-odl.tar.gz:/root/ \
    --upload ${BUILD_DIR}/opendaylight_boron.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "yum install --downloadonly --downloaddir=/root/boron/ opendaylight" \
    --upload ${BUILD_DIR}/opendaylight_master.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "yum install --downloadonly --downloaddir=/root/master/ opendaylight" \
    --upload ${BUILD_DIR}/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --install opendaylight,python-networking-odl \
    --run-command "wget https://github.com/rhuss/jolokia/releases/download/v1.3.3/jolokia-1.3.3-bin.tar.gz -O /tmp/jolokia-1.3.3-bin.tar.gz" \
    --run-command "tar -xvf /tmp/jolokia-1.3.3-bin.tar.gz -C /opt/opendaylight/system/org" \
    --install honeycomb \
    --upload ${BUILD_DIR}/puppet-opendaylight.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-opendaylight.tar.gz" \
    --install https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python2-networking-bgpvpn-5.0.1-dev6.noarch.rpm \
    --install https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-heat-5.0.1-dev6.noarch.rpm \
    --install https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-dashboard-5.0.1-dev6.noarch.rpm \
    -a overcloud-full-opendaylight_build.qcow2

mv overcloud-full-opendaylight_build.qcow2 overcloud-full-opendaylight.qcow2
popd > /dev/null
