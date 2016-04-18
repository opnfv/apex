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
populate_cache "$openstack_congress"

if [ ! -d images/ ]; then mkdir images; fi
tar -xf cache/overcloud-full.tar -C images/
mv -f images/overcloud-full.qcow2 images/overcloud-full_build.qcow2

# Add extra space to the overcloud image
qemu-img resize images/overcloud-full_build.qcow2 +1G
LIBGUESTFS_BACKEND=direct virt-customize -a images/overcloud-full_build.qcow2 \
                                         --run-command 'resize2fs /dev/sda'

##########################################################
#####  Prep initial overcloud image with common deps #####
##########################################################

# prep opnfv-puppet-tripleo for undercloud
clone_fork opnfv-puppet-tripleo
pushd opnfv-puppet-tripleo > /dev/null
git archive --format=tar.gz --prefix=tripleo/ HEAD > ../opnfv-puppet-tripleo.tar.gz
popd > /dev/null

# download customized os-net-config
rm -fr os-net-config
git clone https://github.com/trozet/os-net-config.git -b stable/colorado
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

# tar up the congress puppet module
rm -rf puppet-congress
git clone https://github.com/radez/puppet-congress
pushd puppet-congress > /dev/null
git archive --format=tar.gz --prefix=congress/ origin/stable/mitaka > ../puppet-congress.tar.gz
popd > /dev/null

# create fd.io yum repo file
cat > /tmp/fdio-master.repo << EOF
[fdio-master]
name=fd.io master branch latest merge
baseurl=https://nexus.fd.io/content/repositories/fd.io.master.centos7/
enabled=1
gpgcheck=0
EOF

# tar up the fd.io module
rm -rf puppet-fdio
git clone https://github.com/radez/puppet-fdio
pushd puppet-fdio > /dev/null
git archive --format=tar.gz --prefix=fdio/ HEAD > ../puppet-fdio.tar.gz
popd > /dev/null

# installing forked opnfv-puppet-tripleo
# enable connection tracking for protocal sctp
# upload dpdk rpms but do not install
# enable connection tracking for protocal sctp
# install the congress rpms
# upload and explode the congress puppet module
# install doctor driver ## Can be removed in Newton
# install fd.io yum repo and packages
# upload puppet fdio
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ../opnfv-puppet-tripleo.tar.gz:/etc/puppet/modules \
    --run-command "sed -i 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config" \
    --run-command "sed -i 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config" \
    --run-command "cd /etc/puppet/modules && rm -rf tripleo && tar xzf opnfv-puppet-tripleo.tar.gz" \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --run-command "mkdir /root/dpdk_rpms" \
    $dpdk_pkg_str \
    --install "centos-release-qemu-ev" \
    --run-command "yum update -y" \
    --run-command "yum remove -y qemu-system-x86" \
    --upload ../os-net-config.tar.gz:/usr/lib/python2.7/site-packages \
    --run-command "cd /usr/lib/python2.7/site-packages/ && rm -rf os_net_config && tar xzf os-net-config.tar.gz" \
    --install "$openstack_congress" \
    --install "python2-congressclient" \
    --upload puppet-congress.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-congress.tar.gz" \
    --run-command "cd /usr/lib/python2.7/site-packages/congress/datasources && curl -O $doctor_driver" \
    --run-command "sed -i \"s/'--detailed-exitcodes',/'--detailed-exitcodes','-l','syslog','-l','console',/g\" /var/lib/heat-config/hooks/puppet" \
    --upload /tmp/fdio-master.repo:/etc/yum.repos.d/fdio-master.repo \
    --install unzip,vpp,honeycomb \
    --upload puppet-fdio.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && tar xzf puppet-fdio.tar.gz" \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
