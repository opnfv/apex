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

cat > ${BUILD_DIR}/opendaylight.repo << EOF
[opendaylight-6-release]
name=CentOS CBS OpenDaylight Carbon repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-6-testing/\$basearch/os/
enabled=1
gpgcheck=0
EOF

cat > ${BUILD_DIR}/opendaylight_nitrogen.repo << EOF
[opendaylight-7-release]
name=CentOS CBS OpenDaylight Nitrogen repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-7-testing/\$basearch/os/
enabled=1
gpgcheck=0
EOF

cat > ${BUILD_DIR}/opendaylight_master.repo << EOF
[opendaylight-master]
name=OpenDaylight master repository
baseurl=https://nexus.opendaylight.org/content/repositories/opendaylight-oxygen-epel-7-x86_64-devel/
enabled=1
gpgcheck=0
EOF

# OpenDaylight Puppet Module
rm -rf puppet-opendaylight
git clone -b stable/carbon https://git.opendaylight.org/gerrit/integration/packaging/puppet-opendaylight
pushd puppet-opendaylight > /dev/null
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ${BUILD_DIR}/puppet-opendaylight-carbon.tar.gz
git checkout master
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ${BUILD_DIR}/puppet-opendaylight-master.tar.gz
git checkout stable/nitrogen
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ${BUILD_DIR}/puppet-opendaylight-nitrogen.tar.gz
popd > /dev/null

# cache gluon
populate_cache http://artifacts.opnfv.org/netready/$gluon_rpm

#Gluon puppet module
rm -rf netready
git clone -b master https://gerrit.opnfv.org/gerrit/netready
pushd netready/ > /dev/null
git archive --format=tar.gz HEAD:deploy/puppet/ > ${BUILD_DIR}/puppet-gluon.tar.gz
popd > /dev/null

# Download ODL netvirt for VPP
populate_cache http://artifacts.opnfv.org/apex/danube/fdio_netvirt/opendaylight-7.0.0-0.1.20170531snap665.el7.noarch.rpm

# install ODL packages
# Patch in OPNFV custom puppet-tripleO
# install quagga/zrpc
# upload neutron patch for generic NS linux interface driver + OVS for external networks
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ${BUILD_DIR}/opendaylight_master.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "mkdir -p /root/master" \
    --run-command "yumdownloader --destdir=/root/master opendaylight" \
    --upload ${BUILD_DIR}/opendaylight_nitrogen.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "mkdir -p /root/nitrogen" \
    --run-command "yum install --downloadonly --downloaddir=/root/nitrogen opendaylight" \
    --upload ${BUILD_DIR}/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --install opendaylight,python-networking-odl \
    --upload ${BUILD_DIR}/puppet-opendaylight-carbon.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-opendaylight-carbon.tar.gz" \
    --upload ${BUILD_DIR}/puppet-opendaylight-master.tar.gz:/root/ \
    --upload ${BUILD_DIR}/puppet-opendaylight-nitrogen.tar.gz:/root/ \
    --upload ${BUILD_DIR}/puppet-gluon.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-gluon.tar.gz" \
    --install python-click \
    --upload ${CACHE_DIR}/$gluon_rpm:/root/\
    --install /root/$gluon_rpm \
    --run-command "yum downgrade -y python-zmq-14.3.1" \
    --install capnproto-libs,capnproto \
    --upload ${BUILD_ROOT}/patches/neutron-patch-NSDriver.patch:/usr/lib/python2.7/site-packages/ \
    --upload ${CACHE_DIR}/opendaylight-7.0.0-0.1.20170531snap665.el7.noarch.rpm:/root/ \
    -a overcloud-full-opendaylight_build.qcow2

# Arch dependent on x86
if [ "$(uname -i)" == 'x86_64' ]; then

# Download quagga/zrpc rpms
populate_cache http://artifacts.opnfv.org/apex/danube/quagga/quagga-3.tar.gz

LIBGUESTFS_BACKEND=direct virt-customize \
    --install zeromq-4.1.4 \
    --upload ${CACHE_DIR}/quagga-3.tar.gz:/root/ \
    --run-command "cd /root/ && tar xzf quagga-3.tar.gz" \
    --run-command "cd /root/quagga; packages=\$(ls |grep -vE 'debuginfo|devel|contrib'); yum -y install \$packages" \
    --run-command "sudo usermod -a -G quaggavt quagga" \
    -a overcloud-full-opendaylight_build.qcow2
fi

LIBGUESTFS_BACKEND=direct virt-sparsify --compress overcloud-full-opendaylight_build.qcow2 overcloud-full-opendaylight.qcow2
rm -f overcloud-full-opendaylight_build.qcow2
popd > /dev/null
