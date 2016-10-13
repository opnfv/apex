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
  wget "$dpdk_uri_base/$package"
  dpdk_pkg_str+=" --upload $package:/root/dpdk_rpms"
done

fdio_pkg_str=''
for package in ${fdio_pkgs[@]}; do
  wget "$fdio_uri_base/$package"
  fdio_pkg_str+=" --upload $package:/root/fdio"
done

# tar up the congress puppet module
rm -rf puppet-congress
git clone -b stable/mitaka https://github.com/radez/puppet-congress
pushd puppet-congress > /dev/null
git archive --format=tar.gz --prefix=congress/ origin/stable/mitaka > ../puppet-congress.tar.gz
popd > /dev/null

# create fd.io yum repo file
#cat > /tmp/fdio-master.repo << EOF
#[fdio-master]
#name=fd.io master branch latest merge
#baseurl=https://nexus.fd.io/content/repositories/fd.io.master.centos7/
#enabled=1
#gpgcheck=0
#EOF

# tar up the fd.io module
rm -rf puppet-fdio
git clone https://github.com/radez/puppet-fdio
pushd puppet-fdio > /dev/null
git archive --format=tar.gz --prefix=fdio/ HEAD > ../puppet-fdio.tar.gz
popd > /dev/null

# tar up vsperf
rm -rf vsperf vsperf.tar.gz
git clone https://gerrit.opnfv.org/gerrit/vswitchperf vsperf
tar czf vsperf.tar.gz vsperf

# tar up the tacker puppet module
rm -rf puppet-tacker
# TODO move this back to radez puppet-tacker after PR is accepted
git clone -b fix_db_sync https://github.com/trozet/puppet-tacker
pushd puppet-tacker > /dev/null
git archive --format=tar.gz --prefix=tacker/ HEAD > ../puppet-tacker.tar.gz
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
# git clone vsperf into the overcloud image
# upload the tacker puppet module and untar it
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ../opnfv-puppet-tripleo.tar.gz:/etc/puppet/modules \
    --run-command "if ! rpm -qa | grep python-redis; then yum install -y python-redis; fi" \
    --run-command "sed -i 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config" \
    --run-command "sed -i 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config" \
    --run-command "cd /etc/puppet/modules && rm -rf tripleo && tar xzf opnfv-puppet-tripleo.tar.gz" \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --run-command "mkdir /root/dpdk_rpms" \
    --run-command "mkdir /root/fdio" \
    $dpdk_pkg_str \
    $fdio_pkg_str \
    --upload ../networking-vpp.noarch.rpm:/root/fdio \
    --run-command "pip install distro flask_restful" \
    --run-command "yum install -y etcd" \
    --run-command "pip install python-etcd" \
    --run-command "puppet module install cristifalcas/etcd" \
    --run-command "yum update -y puppet" \
    --install "centos-release-qemu-ev" \
    --run-command "yum update -y qemu-kvm-ev" \
    --run-command "yum remove -y qemu-system-x86" \
    --upload ../os-net-config.tar.gz:/usr/lib/python2.7/site-packages \
    --run-command "cd /usr/lib/python2.7/site-packages/ && rm -rf os_net_config && tar xzf os-net-config.tar.gz" \
    --upload ../noarch/$openstack_congress_pkg:/root/ \
    --install /root/$openstack_congress_pkg \
    --install "python2-congressclient" \
    --upload puppet-congress.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-congress.tar.gz" \
    --run-command "cd /usr/lib/python2.7/site-packages/congress/datasources && curl -O $doctor_driver" \
    --run-command "sed -i \"s/'--detailed-exitcodes',/'--detailed-exitcodes','-l','syslog','-l','console',/g\" /var/lib/heat-config/hooks/puppet" \
    --run-command "yum install -y /root/fdio/*.rpm" \
    --run-command "rm -f /etc/sysctl.d/80-vpp.conf" \
    --install unzip \
    --upload puppet-fdio.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && tar xzf puppet-fdio.tar.gz" \
    --upload vsperf.tar.gz:/var/opt \
    --run-command "cd /var/opt && tar xzf vsperf.tar.gz" \
    --upload ../noarch/python-tackerclient-2015.2-1.trozet.noarch.rpm:/root/ \
    --install /root/python-tackerclient-2015.2-1.trozet.noarch.rpm \
    --upload ../noarch/openstack-tacker-2015.2-1.trozet.noarch.rpm:/root/ \
    --install /root/openstack-tacker-2015.2-1.trozet.noarch.rpm \
    --upload puppet-tacker.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-tacker.tar.gz" \
    --run-command "pip install python-senlinclient" \
    --upload ../neutron/agent/interface/interface.py:/usr/lib/python2.7/site-packages/neutron/agent/linux/ \
    --run-command "mkdir /root/fdio_neutron_l3" \
    --upload ../neutron/agent/l3/namespaces.py:/root/fdio_neutron_l3/ \
    --upload ../neutron/agent/l3/router_info.py:/root/fdio_neutron_l3/ \
    --upload ../puppet-neutron/manifests/agents/ml2/networking-vpp.pp:/etc/puppet/modules/neutron/manifests/agents/ml2/ \
    --upload ../puppet-neutron/manifests/plugins/ml2/networking-vpp.pp:/etc/puppet/modules/neutron/manifests/plugins/ml2/ \
    --upload ../puppet-neutron/lib/puppet/type/neutron_agent_vpp.rb:/etc/puppet/modules/neutron/lib/puppet/type/ \
    --mkdir /etc/puppet/modules/neutron/lib/puppet/provider/neutron_agent_vpp \
    --upload ../puppet-neutron/lib/puppet/provider/neutron_agent_vpp/ini_setting.rb:/etc/puppet/modules/neutron/lib/puppet/provider/neutron_agent_vpp/ \
    -a overcloud-full_build.qcow2

rm -rf ovs_nsh_patches
rm -rf ovs
git clone https://github.com/yyang13/ovs_nsh_patches.git
git clone https://github.com/openvswitch/ovs.git
pushd ovs > /dev/null
git reset --hard 7d433ae57ebb90cd68e8fa948a096f619ac4e2d8
cp ../ovs_nsh_patches/*.patch ./
# Hack for build servers that have no git config
git config user.email "apex@opnfv.com"
git config user.name "apex"
git am *.patch
popd > /dev/null
tar czf ovs.tar.gz ovs

# Required packages to redirect stdin with virt-customize
virt_pkg_str="./$libguestfs_pkg "
wget $virt_uri_base/$libguestfs_pkg
for package in ${virt_pkgs[@]}; do
  wget "$virt_uri_base/$package"
  virt_pkg_str+=" ./$package"
done

if ! sudo yum -y install ${virt_pkg_str}; then
  if [ "$(rpm -q libguestfs)" != "$(rpm -qpf $libguestfs_pkg)" ]; then
    echo "ERROR: Failed to update libguestfs"
    exit 1
  fi
fi



# BUILD NSH OVS
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ../build_ovs_nsh.sh:/root/ \
    --upload ovs.tar.gz:/root/ \
    --run-command "cd /root/ && tar xzf ovs.tar.gz" \
    --run-command "cd /root/ovs && /root/build_ovs_nsh.sh" \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
