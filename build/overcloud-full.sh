#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -xe
source ./cache.sh
source ./variables.sh
source ./functions.sh

populate_cache "$rdo_images_uri/overcloud-full.tar"

if [ ! -d ${BUILD_DIR} ]; then mkdir ${BUILD_DIR}; fi
tar -xf ${CACHE_DIR}/overcloud-full.tar -C ${BUILD_DIR}/
mv -f ${BUILD_DIR}/overcloud-full.qcow2 ${BUILD_DIR}/overcloud-full_build.qcow2

##########################################################
#####  Prep initial overcloud image with common deps #####
##########################################################

pushd ${BUILD_DIR} > /dev/null

# prep opnfv-puppet-tripleo for undercloud
clone_fork opnfv-puppet-tripleo
pushd opnfv-puppet-tripleo > /dev/null
git archive --format=tar.gz --prefix=tripleo/ HEAD > ${BUILD_DIR}/opnfv-puppet-tripleo.tar.gz
popd > /dev/null

# download customized os-net-config
clone_fork os-net-config
pushd os-net-config/os_net_config > /dev/null
git archive --format=tar.gz --prefix=os_net_config/ HEAD > ${BUILD_DIR}/os-net-config.tar.gz
popd > /dev/null

dpdk_pkg_str=''
for package in ${dpdk_rpms[@]}; do
  wget "$dpdk_uri_base/$package"
  dpdk_pkg_str+=" --upload ${BUILD_DIR}/${package}:/root/dpdk_rpms"
done

# tar up the fd.io module
rm -rf puppet-fdio
git clone https://git.fd.io/puppet-fdio
pushd puppet-fdio > /dev/null
git archive --format=tar.gz --prefix=fdio/ HEAD > ${BUILD_DIR}/puppet-fdio.tar.gz
popd > /dev/null

# tar up vsperf
rm -rf vsperf vsperf.tar.gz
git clone https://gerrit.opnfv.org/gerrit/vswitchperf vsperf
tar czf vsperf.tar.gz vsperf

# Master FD.IO Repo
cat > ${BUILD_DIR}/fdio.repo << EOF
[fdio-master]
name=fd.io master branch latest merge
baseurl=https://nexus.fd.io/content/repositories/fd.io.master.centos7/
enabled=1
gpgcheck=0
EOF

# Get Real Time Kernel from kvm4nfv
populate_cache $kvmfornfv_uri_base/$kvmfornfv_kernel_rpm

# packages frozen for fdio scenarios
fdio_pkg_str=''
for package in ${fdio_pkgs[@]}; do
  wget "$package"
  fdio_pkg_str+=" --upload ${BUILD_DIR}/${package##*/}:/root/fdio/"
done

# Increase disk size by 900MB to accommodate more packages
qemu-img resize overcloud-full_build.qcow2 +900MB

# expand file system to max disk size
# installing forked opnfv-puppet-tripleo
# upload dpdk rpms but do not install
# install fd.io yum repo and packages
# upload puppet fdio
# git clone vsperf into the overcloud image
# upload the rt_kvm kernel
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "xfs_growfs /dev/sda" \
    --upload ${BUILD_DIR}/opnfv-puppet-tripleo.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && rm -rf tripleo && tar xzf opnfv-puppet-tripleo.tar.gz" \
    --upload ${BUILD_DIR}/os-net-config.tar.gz:/usr/lib/python2.7/site-packages \
    --run-command "cd /usr/lib/python2.7/site-packages/ && rm -rf os_net_config && tar xzf os-net-config.tar.gz" \
    --run-command "if ! rpm -qa | grep python-redis; then yum install -y python-redis; fi" \
    --run-command "sed -i 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config" \
    --run-command "sed -i 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config" \
    --run-command "mkdir /root/dpdk_rpms" \
    $dpdk_pkg_str \
    --run-command "mkdir /root/fdio" \
    --upload ${BUILD_DIR}/noarch/$netvpp_pkg:/root/fdio \
    $fdio_pkg_str \
    --run-command "yum install -y /root/fdio/*.rpm" \
    --run-command "yum install -y etcd" \
    --install python-etcd \
    --run-command "puppet module install cristifalcas/etcd" \
    --install "centos-release-qemu-ev" \
    --run-command "yum install -y qemu-kvm-ev-2.3.0-31.el7_2.21.1.x86_64" \
    --run-command "yum remove -y qemu-system-x86" \
    --run-command "rm -f /etc/sysctl.d/80-vpp.conf" \
    --install unzip \
    --upload ${BUILD_DIR}/puppet-fdio.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && tar xzf puppet-fdio.tar.gz" \
    --upload ${BUILD_DIR}/vsperf.tar.gz:/var/opt \
    --run-command "cd /var/opt && tar xzf vsperf.tar.gz" \
    --run-command "curl -f https://copr.fedorainfracloud.org/coprs/leifmadsen/ovs-master/repo/epel-7/leifmadsen-ovs-master-epel-7.repo > /etc/yum.repos.d/leifmadsen-ovs-master-epel-7.repo" \
    --run-command "mkdir /root/ovs27" \
    --run-command "yumdownloader --destdir=/root/ovs27 openvswitch*2.7* python-openvswitch-2.7*" \
    --run-command "sed -i -E 's/timeout=[0-9]+/timeout=60/g' /usr/share/openstack-puppet/modules/rabbitmq/lib/puppet/provider/rabbitmqctl.rb" \
    --upload ${CACHE_DIR}/$kvmfornfv_kernel_rpm:/root/ \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
