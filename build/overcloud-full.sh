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
source ./functions.sh

populate_cache "$rdo_images_uri/overcloud-full.tar"

if [ ! -d images/ ]; then mkdir images; fi
tar -xf cache/overcloud-full.tar -C images/
mv -f images/overcloud-full.qcow2 images/overcloud-full_build.qcow2

##########################################################
#####  Prep initial overcloud image with common deps #####
##########################################################

# prep opnfv-puppet-tripleo for undercloud
clone_fork opnfv-puppet-tripleo
pushd opnfv-puppet-tripleo > /dev/null
git archive --format=tar.gz --prefix=tripleo/ HEAD > ../opnfv-puppet-tripleo.tar.gz
popd > /dev/null

# download customized os-net-config
git clone https://github.com/trozet/os-net-config.git -b hiera_nic_mapping
pushd os-net-config > /dev/null
pushd os_net_config > /dev/null
git archive --format=tar.gz --prefix=os_net_config/ HEAD > ../../os-net-config.tar.gz
popd > /dev/null
popd > /dev/null

pushd images > /dev/null

dpdk_pkg_str=''
for package in ${dpdk_rpms[@]}; do
  curl -O "$dpdk_uri_base/$package"
  dpdk_pkg_str+=" --upload $package:/root/dpdk_rpms"
done

# installing forked opnfv-puppet-tripleo
# enable connection tracking for protocal sctp
# upload dpdk rpms but do not install
# Install performance analysis tools
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ../opnfv-puppet-tripleo.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && rm -rf tripleo && tar xzf opnfv-puppet-tripleo.tar.gz" \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --run-command "mkdir /root/dpdk_rpms" \
    $dpdk_pkg_str \
    --install "centos-release-qemu-ev" \
    --run-command "yum update -y" \
    --run-command "yum remove -y qemu-system-x86" \
    --upload ../os-net-config.tar.gz:/usr/lib/python2.7/site-packages \
    --run-command "cd /usr/lib/python2.7/site-packages/ && rm -rf os_net_config && tar xzf os-net-config.tar.gz" \
    --run-command "yum install -y epel-release" \
    --run-command "yum clean all && yum makecache fast" \
    --run-command "yum install -y collectd collectd-rrdtool" \
    --upload ../collectd_client.conf:/etc/collectd.d/10-collectd-client.conf \
    --run-command "systemctl enable collectd" \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
