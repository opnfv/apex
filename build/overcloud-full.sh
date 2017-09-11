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
source ./barometer-install.sh

populate_cache "$rdo_images_uri/overcloud-full.tar"

if [ ! -d ${BUILD_DIR} ]; then mkdir ${BUILD_DIR}; fi
tar -xf ${CACHE_DIR}/overcloud-full.tar -C ${BUILD_DIR}/
mv -f ${BUILD_DIR}/overcloud-full.qcow2 ${BUILD_DIR}/overcloud-full_build.qcow2

##########################################################
#####  Prep initial overcloud image with common deps #####
##########################################################

pushd ${BUILD_DIR} > /dev/null

# prep opnfv-puppet-tripleo for undercloud
python3 -B $BUILD_UTILS clone-fork -r apex-puppet-tripleo
pushd apex-puppet-tripleo > /dev/null
git archive --format=tar.gz --prefix=tripleo/ HEAD > ${BUILD_DIR}/apex-puppet-tripleo.tar.gz
popd > /dev/null

# download customized os-net-config
python3 -B $BUILD_UTILS clone-fork -r apex-os-net-config
pushd apex-os-net-config/os_net_config > /dev/null
git archive --format=tar.gz --prefix=os_net_config/ HEAD > ${BUILD_DIR}/apex-os-net-config.tar.gz
popd > /dev/null

# tar up vsperf
rm -rf vsperf vsperf.tar.gz
git clone https://gerrit.opnfv.org/gerrit/vswitchperf vsperf
tar czf vsperf.tar.gz vsperf

# Increase disk size by 1200MB to accommodate more packages
qemu-img resize overcloud-full_build.qcow2 +1200M

# expand file system to max disk size
# installing forked apex-puppet-tripleo
# upload neutron port data plane status
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "xfs_growfs /dev/sda" \
    --upload ${BUILD_DIR}/apex-puppet-tripleo.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && rm -rf tripleo && tar xzf apex-puppet-tripleo.tar.gz" \
    --upload ${BUILD_DIR}/apex-os-net-config.tar.gz:/usr/lib/python2.7/site-packages \
    --run-command "cd /usr/lib/python2.7/site-packages/ && rm -rf os_net_config && tar xzf apex-os-net-config.tar.gz" \
    --run-command "if ! rpm -qa | grep python-redis; then yum install -y python-redis; fi" \
    --install epel-release \
    --run-command "sed -i 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config" \
    --run-command "sed -i 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config" \
    --install unzip \
    --upload ${BUILD_DIR}/vsperf.tar.gz:/var/opt \
    --run-command "cd /var/opt && tar xzf vsperf.tar.gz" \
    --run-command "sed -i -E 's/timeout=[0-9]+/timeout=60/g' /usr/share/openstack-puppet/modules/rabbitmq/lib/puppet/provider/rabbitmqctl.rb" \
    --install patch \
    --upload ${BUILD_ROOT}/patches/neutron_lib_dps.patch:/usr/lib/python2.7/site-packages/ \
    --upload ${BUILD_ROOT}/patches/neutron_server_dps.patch:/usr/lib/python2.7/site-packages/ \
    --upload ${BUILD_ROOT}/patches/neutron_openstacksdk_dps.patch:/usr/lib/python2.7/site-packages/ \
    --upload ${BUILD_ROOT}/patches/neutron_openstackclient_dps.patch:/usr/lib/python2.7/site-packages/ \
    --upload ${BUILD_ROOT}/patches/puppet-neutron-add-sfc.patch:/usr/share/openstack-puppet/modules/neutron/ \
    --upload ${BUILD_ROOT}/patches/congress-parallel-execution.patch:/usr/lib/python2.7/site-packages/ \
    --upload ${BUILD_ROOT}/patches/puppet-neutron-ml2-ip-version-fix.patch:/usr/share/openstack-puppet/modules/neutron/ \
    --run-command "cd /usr/share/openstack-puppet/modules/neutron && patch -p1 < puppet-neutron-ml2-ip-version-fix.patch" \
    --upload ${BUILD_ROOT}/patches/puppet-neutron-vpp-ml2-type_drivers-setting.patch:/usr/share/openstack-puppet/modules/neutron/ \
    --run-command "cd /usr/share/openstack-puppet/modules/neutron && patch -p1 < puppet-neutron-vpp-ml2-type_drivers-setting.patch" \
    -a overcloud-full_build.qcow2

# apply neutron port data plane status patches
# https://specs.openstack.org/openstack/neutron-specs/specs/backlog/ocata/port-data-plane-status.html
# apply congress parallel execution patch
# Requirements from Doctor project
# TODO(cgoncalves): code merged in Pike dev cycle. drop from >= OpenStack Pike / > OPNFV Euphrates
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "cd /usr/lib/python2.7/site-packages/ && patch -p1 < neutron_lib_dps.patch " \
    --run-command "cd /usr/lib/python2.7/site-packages/ && patch -p1 < neutron_server_dps.patch" \
    --run-command "cd /usr/lib/python2.7/site-packages/ && patch -p1 < neutron_openstacksdk_dps.patch" \
    --run-command "cd /usr/lib/python2.7/site-packages/ && patch -p1 < neutron_openstackclient_dps.patch" \
    --run-command "cd /usr/share/openstack-puppet/modules/neutron && patch -p1 < puppet-neutron-add-sfc.patch" \
    --run-command "cd /usr/lib/python2.7/site-packages/ && patch -p1 < congress-parallel-execution.patch" \
    -a overcloud-full_build.qcow2

# Arch dependent on x86
if [ "$(uname -i)" == 'x86_64' ]; then
dpdk_pkg_str=''
for package in ${dpdk_rpms[@]}; do
  wget "$dpdk_uri_base/$package"
  dpdk_pkg_str+=" --upload ${BUILD_DIR}/${package}:/root/dpdk_rpms"
done

# tar up the fd.io module
rm -rf puppet-fdio
git clone https://git.fd.io/puppet-fdio
pushd puppet-fdio > /dev/null
#TODO: Remove this when we update to 17.07
#git revert a6e575c8f0af17e62990653bcf4a12c688c21aad --no-edit
git archive --format=tar.gz --prefix=fdio/ HEAD > ${BUILD_DIR}/puppet-fdio.tar.gz
popd > /dev/null

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

# upload dpdk rpms but do not install
# install fd.io yum repo and packages
# upload puppet fdio
# git clone vsperf into the overcloud image
# upload the rt_kvm kernel
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "mkdir /root/dpdk_rpms" \
    $dpdk_pkg_str \
    --upload ${BUILD_DIR}/puppet-fdio.tar.gz:/etc/puppet/modules \
    --run-command "cd /etc/puppet/modules && tar xzf puppet-fdio.tar.gz" \
    --upload ${BUILD_DIR}/fdio.repo:/etc/yum.repos.d/ \
    --run-command "mkdir /root/fdio" \
    --upload ${BUILD_DIR}/noarch/$netvpp_pkg:/root/fdio \
    --install honeycomb \
    --install vpp-plugins \
    --run-command "rm -f /etc/sysctl.d/80-vpp.conf" \
    --run-command "yum install -y /root/fdio/*.rpm" \
    --run-command "curl -f https://copr.fedorainfracloud.org/coprs/leifmadsen/ovs-master/repo/epel-7/leifmadsen-ovs-master-epel-7.repo > /etc/yum.repos.d/leifmadsen-ovs-master-epel-7.repo" \
    --run-command "mkdir /root/ovs28" \
    --run-command "yumdownloader --destdir=/root/ovs28 openvswitch*2.8* python-openvswitch-2.8*" \
    --upload ${CACHE_DIR}/$kvmfornfv_kernel_rpm:/root/ \
    --install python2-networking-sfc \
    --install python-etcd,puppet-etcd \
    --install patch \
    -a overcloud-full_build.qcow2

    # upload and install barometer packages
    barometer_pkgs overcloud-full_build.qcow2

    # Build OVS with NSH
    rm -rf ovs_nsh_patches
    rm -rf ovs
    git clone https://github.com/yyang13/ovs_nsh_patches.git
    git clone https://github.com/openvswitch/ovs.git
    pushd ovs > /dev/null
    git checkout v2.6.1
    cp ../ovs_nsh_patches/v2.6.1/*.patch ./
    cp ${BUILD_ROOT}/patches/ovs-fix-build-on-RHEL-7.3.patch ./
    # Hack for build servers that have no git config
    git config user.email "apex@opnfv.com"
    git config user.name "apex"
    git am *.patch
    popd > /dev/null
    tar czf ovs.tar.gz ovs


LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ${BUILD_ROOT}/CentOS-Updates.repo:/etc/yum.repos.d/ \
    --run-command "yum -y install kernel-devel-\$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' kernel)" \
    --run-command "yum -y install kernel-headers-\$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' kernel)" \
    --run-command "yum -y install kernel-tools-\$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' kernel)" \
    --upload ${BUILD_ROOT}/build_ovs_nsh.sh:/root/ \
    --upload ovs.tar.gz:/root/ \
    --run-command "cd /root/ && tar xzf ovs.tar.gz" \
    --run-command "cd /root/ovs && /root/build_ovs_nsh.sh" \
    -a overcloud-full_build.qcow2

fi # end x86_64 specific items

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
