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
rm -fr os-net-config
git clone https://github.com/trozet/os-net-config.git -b stable/colorado
pushd os-net-config/os_net_config > /dev/null
git archive --format=tar.gz --prefix=os_net_config/ HEAD > ${BUILD_DIR}/os-net-config.tar.gz
popd > /dev/null

dpdk_pkg_str=''
for package in ${dpdk_rpms[@]}; do
  wget "$dpdk_uri_base/$package"
  dpdk_pkg_str+=" --upload ${BUILD_DIR}/${package}:/root/dpdk_rpms"
done

# tar up the congress puppet module
rm -rf puppet-congress
git clone -b stable/mitaka https://github.com/radez/puppet-congress
pushd puppet-congress > /dev/null
git archive --format=tar.gz --prefix=congress/ origin/stable/mitaka > ${BUILD_DIR}/puppet-congress.tar.gz
popd > /dev/null

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

# tar up the tacker puppet module
rm -rf puppet-tacker
git clone https://github.com/openstack/puppet-tacker
pushd puppet-tacker > /dev/null
git archive --format=tar.gz --prefix=tacker/ HEAD > ${BUILD_DIR}/puppet-tacker.tar.gz
popd > /dev/null

# Master FD.IO Repo
cat > ${BUILD_DIR}/fdio.repo << EOF
[fdio-master]
name=fd.io master branch latest merge
baseurl=https://nexus.fd.io/content/repositories/fd.io.master.centos7/
enabled=1
gpgcheck=0
EOF

# Increase disk size by 500MB to accommodate more packages
qemu-img resize overcloud-full_build.qcow2 +500MB

# expand file system to max disk size
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
# install tacker
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "xfs_growfs /dev/sda" \
    --upload ${BUILD_DIR}/opnfv-puppet-tripleo.tar.gz:/etc/puppet/modules \
    --run-command "yum update -y python-ipaddress rabbitmq-server erlang*" \
    --run-command "if ! rpm -qa | grep python-redis; then yum install -y python-redis; fi" \
    --run-command "sed -i 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config" \
    --run-command "sed -i 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config" \
    --run-command "cd /etc/puppet/modules && rm -rf tripleo && tar xzf opnfv-puppet-tripleo.tar.gz" \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --run-command "mkdir /root/dpdk_rpms" \
    --upload ${BUILD_DIR}/fdio.repo:/etc/yum.repos.d/fdio.repo \
    $dpdk_pkg_str \
    --run-command "yum install --downloadonly --downloaddir=/root/fdio vpp vpp-devel vpp-lib vpp-python-api vpp-plugins" \
    --upload ${BUILD_DIR}/noarch/$netvpp_pkg:/root/fdio \
    --run-command "yum install -y etcd" \
    --run-command "pip install python-etcd" \
    --run-command "puppet module install cristifalcas/etcd" \
    --run-command "yum update -y puppet" \
    --install "centos-release-qemu-ev" \
    --run-command "yum install -y qemu-kvm-ev-2.3.0-31.el7_2.21.1.x86_64" \
    --run-command "yum remove -y qemu-system-x86" \
    --upload ${BUILD_DIR}/os-net-config.tar.gz:/usr/lib/python2.7/site-packages \
    --run-command "cd /usr/lib/python2.7/site-packages/ && rm -rf os_net_config && tar xzf os-net-config.tar.gz" \
    --upload ${BUILD_DIR}/noarch/$congress_pkg:/root/ \
    --install /root/$congress_pkg \
    --install "python2-congressclient" \
    --upload ${BUILD_DIR}/puppet-congress.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-congress.tar.gz" \
    --run-command "cd /usr/lib/python2.7/site-packages/congress/datasources && curl -O $doctor_driver" \
    --run-command "yum install -y /root/fdio/*.rpm" \
    --run-command "rm -f /etc/sysctl.d/80-vpp.conf" \
    --install unzip \
    --upload ${BUILD_DIR}/puppet-fdio.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && tar xzf puppet-fdio.tar.gz" \
    --upload ${BUILD_DIR}/vsperf.tar.gz:/var/opt \
    --run-command "cd /var/opt && tar xzf vsperf.tar.gz" \
    --upload ${BUILD_DIR}/puppet-tacker.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-tacker.tar.gz" \
    --upload ${BUILD_DIR}/noarch/$tacker_pkg:/root/ \
    --install /root/$tacker_pkg \
    --upload ${BUILD_DIR}/noarch/$tackerclient_pkg:/root/ \
    --install /root/$tackerclient_pkg \
    --run-command "pip install python-senlinclient" \
    --upload ${BUILD_ROOT}/neutron/agent/interface/interface.py:/usr/lib/python2.7/site-packages/neutron/agent/linux/ \
    --run-command "mkdir /root/fdio_neutron_l3" \
    --upload ${BUILD_ROOT}/neutron/agent/l3/namespaces.py:/root/fdio_neutron_l3/ \
    --upload ${BUILD_ROOT}/neutron/agent/l3/router_info.py:/root/fdio_neutron_l3/ \
    --upload ${BUILD_ROOT}/puppet-neutron/manifests/agents/ml2/networking-vpp.pp:/etc/puppet/modules/neutron/manifests/agents/ml2/ \
    --upload ${BUILD_ROOT}/puppet-neutron/manifests/plugins/ml2/networking-vpp.pp:/etc/puppet/modules/neutron/manifests/plugins/ml2/ \
    --upload ${BUILD_ROOT}/puppet-neutron/lib/puppet/type/neutron_agent_vpp.rb:/etc/puppet/modules/neutron/lib/puppet/type/ \
    --mkdir /etc/puppet/modules/neutron/lib/puppet/provider/neutron_agent_vpp \
    --upload ${BUILD_ROOT}/puppet-neutron/lib/puppet/provider/neutron_agent_vpp/ini_setting.rb:/etc/puppet/modules/neutron/lib/puppet/provider/neutron_agent_vpp/ \
    --run-command "sed -i -E 's/timeout=[0-9]+/timeout=60/g' /usr/share/openstack-puppet/modules/rabbitmq/lib/puppet/provider/rabbitmqctl.rb" \
    --upload ${BUILD_ROOT}/osc_auth_fix.diff:/tmp/ \
    --run-command "cd /usr/lib/python2.7/site-packages/ && git apply /tmp/osc_auth_fix.diff" \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
