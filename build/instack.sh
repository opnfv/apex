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
declare -i CNT

#rdo_images_uri=https://repos.fedorapeople.org/repos/openstack-m/rdo-images-centos-liberty-opnfv
rdo_images_uri=file:///stable-images
onos_artifacts_uri=file:///stable-images/onos

vm_index=4
RDO_RELEASE=liberty
SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null)
OPNFV_NETWORK_TYPES="admin_network private_network public_network storage_network"

# check for dependancy packages
for i in rpm-build createrepo libguestfs-tools python-docutils bsdtar; do
    if ! rpm -q $i > /dev/null; then
        sudo yum install -y $i
    fi
done

# RDO Manager expects a stack user to exist, this checks for one
# and creates it if you are root
if ! id stack > /dev/null; then
    sudo useradd stack;
    sudo echo 'stack ALL=(root) NOPASSWD:ALL' | sudo tee -a /etc/sudoers.d/stack
    sudo echo 'Defaults:stack !requiretty' | sudo tee -a /etc/sudoers.d/stack
    sudo chmod 0440 /etc/sudoers.d/stack
    echo 'Added user stack'
fi

# ensure that I can ssh as the stack user
if ! sudo grep "$(cat ~/.ssh/id_rsa.pub)" /home/stack/.ssh/authorized_keys; then
    if ! sudo ls -d /home/stack/.ssh/ ; then
        sudo mkdir /home/stack/.ssh
        sudo chown stack:stack /home/stack/.ssh
        sudo chmod 700 /home/stack/.ssh
    fi
    USER=$(whoami) sudo sh -c "cat ~$USER/.ssh/id_rsa.pub >> /home/stack/.ssh/authorized_keys"
    sudo chown stack:stack /home/stack/.ssh/authorized_keys
fi

# clean up stack user previously build instack disk images
ssh -T ${SSH_OPTIONS[@]} stack@localhost "rm -f instack*.qcow2"

# Yum repo setup for building the undercloud
if ! rpm -q rdo-release > /dev/null && [ "$1" != "-master" ]; then
    #pulling from current-passed-ci instead of release repos
    #sudo yum install -y https://rdoproject.org/repos/openstack-${RDO_RELEASE}/rdo-release-${RDO_RELEASE}.rpm
    sudo yum -y install yum-plugin-priorities
    sudo yum-config-manager --disable openstack-${RDO_RELEASE}
    sudo curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7-liberty/current-passed-ci/delorean.repo
    sudo curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7-liberty/delorean-deps.repo
    sudo rm -f /etc/yum.repos.d/delorean-current.repo
elif [ "$1" == "-master" ]; then
    sudo yum -y install yum-plugin-priorities
    sudo yum-config-manager --disable openstack-${RDO_RELEASE}
    sudo curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7/current-passed-ci/delorean.repo
    sudo curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7-liberty/delorean-deps.repo
    sudo rm -f /etc/yum.repos.d/delorean-current.repo
fi

# ensure the undercloud package is installed so we can build the undercloud
if ! rpm -q instack-undercloud > /dev/null; then
    sudo yum install -y python-tripleoclient
fi

# ensure openvswitch is installed
if ! rpm -q openvswitch > /dev/null; then
    sudo yum install -y openvswitch
fi

# ensure libvirt is installed
if ! rpm -q libvirt-daemon-kvm > /dev/null; then
    sudo yum install -y libvirt-daemon-kvm
fi

# clean this up incase it's there
sudo rm -f /tmp/instack.answers

# ensure that no previous undercloud VMs are running
sudo ../ci/clean.sh
# and rebuild the bare undercloud VMs
ssh -T ${SSH_OPTIONS[@]} stack@localhost <<EOI
set -e
NODE_COUNT=5 NODE_CPU=2 NODE_MEM=8192 TESTENV_ARGS="--baremetal-bridge-names 'brbm brbm1 brbm2 brbm3'" instack-virt-setup
EOI

# let dhcp happen so we can get the ip
# just wait instead of checking until we see an address
# because there may be a previous lease that needs
# to be cleaned up
sleep 5

# get the undercloud ip address
UNDERCLOUD=$(grep instack /var/lib/libvirt/dnsmasq/default.leases | awk '{print $3}' | head -n 1)
if [ -z "$UNDERCLOUD" ]; then
  #if not found then dnsmasq may be using leasefile-ro
  instack_mac=$(ssh -T ${SSH_OPTIONS[@]} stack@localhost "virsh domiflist instack" | grep default | \
                grep -Eo "[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+")
  UNDERCLOUD=$(/usr/sbin/arp -e | grep ${instack_mac} | awk {'print $1'})

  if [ -z "$UNDERCLOUD" ]; then
    echo "\n\nNever got IP for Instack. Can Not Continue."
    exit 1
  else
    echo -e "${blue}\rInstack VM has IP $UNDERCLOUD${reset}"
  fi
else
   echo -e "${blue}\rInstack VM has IP $UNDERCLOUD${reset}"
fi

# ensure that we can ssh to the undercloud
CNT=10
while ! ssh -T ${SSH_OPTIONS[@]}  "root@$UNDERCLOUD" "echo ''" > /dev/null && [ $CNT -gt 0 ]; do
    echo -n "."
    sleep 3
    CNT=CNT-1
done
# TODO fail if CNT=0

# yum repo, triple-o package and ssh key setup for the undercloud
ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" <<EOI
set -e

if ! rpm -q epel-release > /dev/null; then
    yum install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

yum -y install yum-plugin-priorities
curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7-liberty/current-passed-ci/delorean.repo
curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7-liberty/delorean-deps.repo

cp /root/.ssh/authorized_keys /home/stack/.ssh/authorized_keys
chown stack:stack /home/stack/.ssh/authorized_keys
EOI

# copy instackenv file for future virt deployments
if [ ! -d stack ]; then mkdir stack; fi
scp ${SSH_OPTIONS[@]} stack@$UNDERCLOUD:instackenv.json stack/instackenv.json

# make a copy of instack VM's definitions, and disk image
# it must be stopped to make a copy of its disk image
ssh -T ${SSH_OPTIONS[@]} stack@localhost <<EOI
set -e
echo "Shutting down instack to gather configs"
virsh shutdown instack

echo "Waiting for instack VM to shutdown"
CNT=20
while virsh list | grep instack > /dev/null && [ $CNT -gt 0 ]; do
    echo -n "."
    sleep 5
    CNT=CNT-1
done
if virsh list | grep instack > /dev/null; then
    echo "instack failed to shutdown for copy"
    exit 1
fi

echo $'\nGenerating libvirt configuration'
for i in \$(seq 0 $vm_index); do
  virsh dumpxml baremetalbrbm_brbm1_brbm2_brbm3_\$i | awk '/model type='\''virtio'\''/{c++;if(c==2){sub("model type='\''virtio'\''","model type='\''rtl8139'\''");c=0}}1' > baremetalbrbm_brbm1_brbm2_brbm3_\$i.xml
done

virsh dumpxml instack > instack.xml
virsh net-dumpxml brbm > brbm-net.xml
virsh net-dumpxml brbm1 > brbm1-net.xml
virsh net-dumpxml brbm2> brbm2-net.xml
virsh net-dumpxml brbm3 > brbm3-net.xml
virsh pool-dumpxml default > default-pool.xml
EOI

# copy off the instack artifacts
echo "Copying instack files to build directory"
for i in $(seq 0 $vm_index); do
  scp ${SSH_OPTIONS[@]} stack@localhost:baremetalbrbm_brbm1_brbm2_brbm3_${i}.xml .
done

scp ${SSH_OPTIONS[@]} stack@localhost:instack.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:brbm-net.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:brbm1-net.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:brbm2-net.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:brbm3-net.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:default-pool.xml .

# pull down the the built images
echo "Copying overcloud resources"
IMAGES="overcloud-full.tar"
IMAGES+=" undercloud.qcow2"

for i in $IMAGES; do
  # download prebuilt images from RDO Project
  if [ "$(curl -L $rdo_images_uri/${i}.md5 | awk {'print $1'})" != "$(md5sum stack/$i | awk {'print $1'})" ] ; then
    #if [ $i == "undercloud.qcow2" ]; then
    ### there's a problem with the Content-Length reported by the centos artifacts
    ### server so using wget for it until a resolution is figured out.
    #wget -nv -O stack/$i $rdo_images_uri/$i
    #else
    curl $rdo_images_uri/$i -o stack/$i
    #fi
  fi
  # only untar the tar files
  if [ "${i##*.}" == "tar" ]; then tar -xf stack/$i -C stack/; fi
done

#Adding OpenStack packages to undercloud
pushd stack
cp undercloud.qcow2 instack.qcow2
LIBGUESTFS_BACKEND=direct virt-customize --install yum-priorities -a instack.qcow2
PACKAGES="qemu-kvm-common,qemu-kvm,libvirt-daemon-kvm,libguestfs,python-libguestfs,openstack-nova-compute"
PACKAGES+=",openstack-swift,openstack-ceilometer-api,openstack-neutron-ml2,openstack-ceilometer-alarm"
PACKAGES+=",openstack-nova-conductor,openstack-ironic-inspector,openstack-ironic-api,python-openvswitch"
PACKAGES+=",openstack-glance,python-glance,python-troveclient,openstack-puppet-modules"
PACKAGES+=",openstack-neutron,openstack-neutron-openvswitch,openstack-nova-scheduler,openstack-keystone,openstack-swift-account"
PACKAGES+=",openstack-swift-container,openstack-swift-object,openstack-swift-plugin-swift3,openstack-swift-proxy"
PACKAGES+=",openstack-nova-api,openstack-nova-cert,openstack-heat-api-cfn,openstack-heat-api,"
PACKAGES+=",openstack-ceilometer-central,openstack-ceilometer-polling,openstack-ceilometer-collector,"
PACKAGES+=",openstack-heat-api-cloudwatch,openstack-heat-engine,openstack-heat-common,openstack-ceilometer-notification"
PACKAGES+=",hiera,puppet,memcached,keepalived,mariadb,mariadb-server,rabbitmq-server,python-pbr,python-proliantutils"
PACKAGES+=",ceph-common"

# install the packages above and enabling ceph to live on the controller
LIBGUESTFS_BACKEND=direct virt-customize --install $PACKAGES \
    --run-command "sed -i '/ControllerEnableCephStorage/c\\  ControllerEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller_pacemaker.pp" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller.pp" \
    -a instack.qcow2
popd


pushd stack

##########################################################
#####  Prep initial overcloud image with common deps #####
##########################################################

# make a copy of the cached overcloud-full image
cp overcloud-full.qcow2 overcloud-full-opendaylight.qcow2
# Update puppet-aodh it's old
rm -rf aodh
git clone https://github.com/openstack/puppet-aodh aodh
pushd aodh
git checkout stable/liberty
popd
tar -czf puppet-aodh.tar.gz aodh

# Add epel, aodh and ceph
AODH_PKG="openstack-aodh-api,openstack-aodh-common,openstack-aodh-compat,openstack-aodh-evaluator,openstack-aodh-expirer"
AODH_PKG+=",openstack-aodh-listener,openstack-aodh-notifier"
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload puppet-aodh.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && rm -rf aodh && tar xzf puppet-aodh.tar.gz" \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --run-command "if ! rpm -q epel-release > /dev/null; then yum install -y http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm; fi" \
    --install https://github.com/michaeltchapman/networking_rpm/raw/master/openstack-neutron-bgpvpn-2015.2-1.el7.centos.noarch.rpm \
    --install "$AODH_PKG,ceph" \
    -a overcloud-full-opendaylight.qcow2

###############################################
#####    Adding OpenDaylight to overcloud #####
###############################################

cat > /tmp/opendaylight.repo << EOF
[opendaylight]
name=OpenDaylight \$releasever - \$basearch
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-4-testing/\$basearch/os/
enabled=1
gpgcheck=0
EOF

odlrpm=opendaylight-4.0.0-1.rc3.1.el7.noarch.rpm
LIBGUESTFS_BACKEND=direct virt-customize --upload ${rdo_images_uri/file:\/\//}/$odlrpm:/tmp/ \
    -a overcloud-full-opendaylight.qcow2
opendaylight=/tmp/$odlrpm

# install ODL packages
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload /tmp/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --install ${opendaylight},python-networking-odl \
    -a overcloud-full-opendaylight.qcow2

## WORK AROUND
## when OpenDaylight lands in upstream RDO manager this can be removed

# upload the opendaylight puppet module
rm -rf puppet-opendaylight
cp ${rdo_images_uri/file:\/\//}/puppet-opendaylight-3.2.2.tar.gz puppet-opendaylight.tar.gz
LIBGUESTFS_BACKEND=direct virt-customize --upload puppet-opendaylight.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-opendaylight.tar.gz" \
                                         --upload ../opendaylight-puppet-neutron.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/neutron && patch -Np1 < /tmp/opendaylight-puppet-neutron.patch" \
                                         -a overcloud-full-opendaylight.qcow2

# Patch in OpenDaylight installation and configuration
LIBGUESTFS_BACKEND=direct virt-customize --upload ../opnfv-tripleo-heat-templates.patch:/tmp \
                                         --run-command "cd /usr/share/openstack-tripleo-heat-templates/ && patch -Np1 < /tmp/opnfv-tripleo-heat-templates.patch" \
                                         -a instack.qcow2

# REMOVE ME AFTER Brahmaputra
LIBGUESTFS_BACKEND=direct virt-customize --upload ../puppet-neutron-force-metadata.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/neutron && patch -Np1 < /tmp/puppet-neutron-force-metadata.patch" \
                                         -a overcloud-full-opendaylight.qcow2

LIBGUESTFS_BACKEND=direct virt-customize --upload ../puppet-cinder-quota-fix.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/cinder && patch -Np1 < /tmp/puppet-cinder-quota-fix.patch" \
                                         -a overcloud-full-opendaylight.qcow2

LIBGUESTFS_BACKEND=direct virt-customize --upload ../aodh-puppet-tripleo.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/tripleo && patch -Np1 < /tmp/aodh-puppet-tripleo.patch" \
                                         -a overcloud-full-opendaylight.qcow2

# adds tripleoclient aodh workaround
# for keystone
LIBGUESTFS_BACKEND=direct virt-customize --upload ../aodh-tripleoclient.patch:/tmp \
                                         --run-command "cd /usr/lib/python2.7/site-packages/tripleoclient && patch -Np1 < /tmp/aodh-tripleoclient.patch" \
                                         --upload ../aodh-os-cloud-config.patch:/tmp \
                                         --run-command "cd /usr/lib/python2.7/site-packages/os_cloud_config && patch -Np1 < /tmp/aodh-os-cloud-config.patch" \
                                         -a instack.qcow2
# END REMOVE ME AFTER Brahmaputra

################################################
#####    Adding SFC+OpenDaylight overcloud #####
################################################

# work around for XFS grow bug
# http://xfs.org/index.php/XFS_FAQ#Q:_Why_do_I_receive_No_space_left_on_device_after_xfs_growfs.3F
cat > /tmp/xfs-grow-remount-fix.service << EOF
[Unit]
Description=XFS Grow Bug Remount
After=network.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo 'XFS Grow Bug Remount Sleeping 180s' && sleep 180 && echo 'XFS Grow Bug Remounting Now' && mount -o remount,inode64 /"
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF


#copy opendaylight overcloud full to isolate odl-sfc
cp overcloud-full-opendaylight.qcow2 overcloud-full-opendaylight-sfc.qcow2

# kernel is patched with patch from this post
# http://xfs.org/index.php/XFS_FAQ#Q:_Why_do_I_receive_No_space_left_on_device_after_xfs_growfs.3F
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload "/tmp/xfs-grow-remount-fix.service:/etc/systemd/system/xfs-grow-remount-fix.service" \
    --run-command "chmod 664 /etc/systemd/system/xfs-grow-remount-fix.service" \
    --run-command "systemctl enable xfs-grow-remount-fix.service" \
    --install 'https://radez.fedorapeople.org/kernel-ml-3.13.7-1.el7.centos.x86_64.rpm' \
    --run-command 'grub2-set-default "\$(grep -P \"submenu|^menuentry\" /boot/grub2/grub.cfg | cut -d \"\\x27\" | head -n 1)"' \
    --install 'https://radez.fedorapeople.org/openvswitch-kmod-2.3.90-1.el7.centos.x86_64.rpm' \
    --run-command 'yum downgrade -y https://radez.fedorapeople.org/openvswitch-2.3.90-1.x86_64.rpm' \
    --run-command 'rm -f /lib/modules/3.13.7-1.el7.centos.x86_64/kernel/net/openvswitch/openvswitch.ko' \
    --run-command 'ln -s /lib/modules/3.13.7-1.el7.centos.x86_64/kernel/extra/openvswitch/openvswitch.ko /lib/modules/3.13.7-1.el7.centos.x86_64/kernel/net/openvswitch/openvswitch.ko' \
    -a overcloud-full-opendaylight-sfc.qcow2



###############################################
#####    Adding ONOS to overcloud #####
###############################################

## WORK AROUND
## when ONOS lands in upstream OPNFV artifacts this can be removed

# upload the onos puppet module

rm -rf puppet-onos
git clone https://github.com/bobzhouHW/puppet-onos.git
pushd puppet-onos
# download jdk, onos and maven dependancy packages.
pushd files
curl ${onos_artifacts_uri}/jdk-8u51-linux-x64.tar.gz -o ./jdk-8u51-linux-x64.tar.gz
curl ${onos_artifacts_uri}/onos-1.3.0.tar.gz -o ./onos-1.3.0.tar.gz
curl ${onos_artifacts_uri}/repository.tar -o ./repository.tar
popd
popd
mv puppet-onos onos
tar -czf puppet-onos.tar.gz onos
LIBGUESTFS_BACKEND=direct virt-customize --upload puppet-onos.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-onos.tar.gz" -a overcloud-full-opendaylight.qcow2

## END WORK AROUND

popd

# move and Sanitize private keys from instack.json file
mv stack/instackenv.json instackenv-virt.json
sed -i '/pm_password/c\      "pm_password": "INSERT_STACK_USER_PRIV_KEY",' instackenv-virt.json
sed -i '/ssh-key/c\  "ssh-key": "INSERT_STACK_USER_PRIV_KEY",' instackenv-virt.json

# clean up the VMs
ssh -T ${SSH_OPTIONS[@]} stack@localhost <<EOI
set -e
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack --remove-all-storage 2> /dev/null || echo -n ''
for i in \$(seq 0 $vm_index); do
  virsh destroy baremetalbrbm_brbm1_brbm2_brbm3_\$i 2> /dev/null || echo -n ''
  virsh undefine baremetalbrbm_brbm1_brbm2_brbm3_\$i --remove-all-storage 2> /dev/null || echo -n ''
done
EOI

