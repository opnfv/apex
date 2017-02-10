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

# networking-BGPVPN
rm -rf networking-bgpvpn
mkdir networking-bgpvpn
pushd networking-bgpvpn > /dev/null
wget https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python2-networking-bgpvpn-5.0.1-dev6.noarch.rpm
wget https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-heat-5.0.1-dev6.noarch.rpm
wget https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-dashboard-5.0.1-dev6.noarch.rpm
wget https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-doc-5.0.1-dev6.noarch.rpm
wget https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-tests-5.0.1-dev6.noarch.rpm
popd > /dev/null
tar czf networking-bgpvpn.tar.gz networking-bgpvpn/

# Tar up all quagga/zrpc rpms
pushd ${QUAGGA_RPMS_DIR}/rpmbuild/RPMS > /dev/null
tar --transform "s/^x86_64/quagga/" -czvf ${BUILD_DIR}/quagga.tar.gz x86_64/
popd > /dev/null

# install ODL packages
# install Jolokia for ODL HA
# Patch in OPNFV custom puppet-tripleO
# install Honeycomb
# install quagga/zrpc
LIBGUESTFS_BACKEND=direct virt-customize \
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
    --upload ${BUILD_DIR}/networking-bgpvpn.tar.gz:/root/ \
    --run-command "cd /root/ && tar xzf networking-bgpvpn.tar.gz && cd networking-bgpvpn/ && yum localinstall python2-networking-bgpvpn && rm -rf /root/networking-bgpvpn*" \
    --upload ${BUILD_DIR}/quagga.tar.gz:/root/ \
    --run-command "cd /root/ && tar xzf quagga.tar.gz" \
    --install epel-release \
    --install zeromq-4.1.4,zeromq-devel-4.1.4 \
    --install capnproto-devel,capnproto-libs,capnproto \
    -a overcloud-full-opendaylight_build.qcow2

mv overcloud-full-opendaylight_build.qcow2 overcloud-full-opendaylight.qcow2
popd > /dev/null
