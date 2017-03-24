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
source ./cache.sh
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

# cache networking-BGPVPN
populate_cache https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python2-networking-bgpvpn-5.0.1-dev6.noarch.rpm
populate_cache https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-heat-5.0.1-dev6.noarch.rpm
populate_cache https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-dashboard-5.0.1-dev6.noarch.rpm
populate_cache https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-doc-5.0.1-dev6.noarch.rpm
populate_cache https://github.com/oglok/networking-bgpvpn-rpm/raw/stable/newton/python-networking-bgpvpn-tests-5.0.1-dev6.noarch.rpm
pushd ${CACHE_DIR}/ > /dev/null
tar czf ${BUILD_DIR}/networking-bgpvpn.tar.gz *networking-bgpvpn*
popd > /dev/null

# cache gluon
populate_cache http://artifacts.opnfv.org/netready/$gluon_rpm

#Gluon puppet module
rm -rf netready
git clone -b master https://gerrit.opnfv.org/gerrit/netready
pushd netready/ > /dev/null
git archive --format=tar.gz HEAD:deploy/puppet/ > ${BUILD_DIR}/puppet-gluon.tar.gz
popd > /dev/null

# Download quagga/zrpc rpms
populate_cache http://artifacts.opnfv.org/apex/danube/quagga/quagga.tar.gz

# install ODL packages
# Patch in OPNFV custom puppet-tripleO
# install Honeycomb
# install quagga/zrpc
# upload neutron patch for generic NS linux interface driver + OVS for external networks
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ${BUILD_DIR}/opendaylight_boron.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "yum install --downloadonly --downloaddir=/root/boron/ opendaylight" \
    --upload ${BUILD_DIR}/opendaylight_master.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "yum install --downloadonly --downloaddir=/root/master/ opendaylight" \
    --upload ${BUILD_DIR}/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "wget ${fdio_l2_uri_base}/honeycomb-1.17.04-2439.noarch.rpm -O /root/fdio_l2/honeycomb-1.17.04-2439.noarch.rpm" \
    --run-command "wget ${fdio_l2_uri_base}/opendaylight-6.0.0-0.1.20170228snap4111.el7.noarch.rpm -O /root/fdio_l2/opendaylight-6.0.0-0.1.20170228snap4111.el7.noarch.rpm" \
    --install opendaylight,python-networking-odl \
    --run-command "yum install -y /root/fdio_l2/honeycomb-1.17.04-2439.noarch.rpm" \
    --upload ${BUILD_DIR}/puppet-opendaylight.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-opendaylight.tar.gz" \
    --upload ${BUILD_DIR}/networking-bgpvpn.tar.gz:/root/ \
    --run-command "cd /root/ && tar xzf networking-bgpvpn.tar.gz && yum localinstall -y *networking-bgpvpn*.rpm" \
    --run-command "rm -f /etc/neutron/networking_bgpvpn.conf" \
    --run-command "touch /etc/neutron/networking_bgpvpn.conf" \
    --upload ${BUILD_DIR}/puppet-gluon.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-gluon.tar.gz" \
    --install epel-release \
    --install python-click \
    --upload ${CACHE_DIR}/$gluon_rpm:/root/\
    --install /root/$gluon_rpm \
    --upload ${CACHE_DIR}/quagga.tar.gz:/root/ \
    --run-command "cd /root/ && tar xzf quagga.tar.gz" \
    --run-command "yum downgrade -y python-zmq-14.3.1" \
    --install zeromq-4.1.4,zeromq-devel-4.1.4 \
    --install capnproto-devel,capnproto-libs,capnproto \
    --upload ${BUILD_ROOT}/patches/neutron-patch-NSDriver.patch:/usr/lib/python2.7/site-packages/ \
    --upload ${BUILD_ROOT}/patches/honeycomb_vpp_mount_restart.patch:/etc/puppet/modules/fdio/ \
    --run-command "cd /etc/puppet/modules/fdio && patch -p1 <  honeycomb_vpp_mount_restart.patch" \
    -a overcloud-full-opendaylight_build.qcow2

LIBGUESTFS_BACKEND=direct virt-sparsify --compress overcloud-full-opendaylight_build.qcow2 overcloud-full-opendaylight.qcow2
popd > /dev/null
