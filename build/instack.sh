#!/bin/sh
set -e
declare -i CNT

RDO_RELEASE=kilo

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
ssh -T -o "StrictHostKeyChecking no" stack@localhost "rm -f instack*.qcow2"

# Yum repo setup for building the undercloud
if ! rpm -q epel-release > /dev/null; then
    sudo yum install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

if ! rpm -q rdo-release > /dev/null; then
    sudo yum install -y https://rdoproject.org/repos/openstack-${RDO_RELEASE}/rdo-release-${RDO_RELEASE}.rpm
fi

if ! rpm -q rdo-release > /dev/null && [ "$1" != "-master" ]; then
    sudo yum install -y https://rdoproject.org/repos/openstack-${RDO_RELEASE}/rdo-release-${RDO_RELEASE}.rpm
    sudo rm -rf /etc/yum.repos.d/delorean.repo
    sudo rm -rf /etc/yum.repos.d/delorean-current.repo
    sudo rm -rf /etc/yum.repos.d/delorean-deps.repo
elif [ "$1" == "-master" ]; then
    sudo yum -y install yum-plugin-priorities
    sudo yum-config-manager --disable openstack-${RDO_RELEASE}
    sudo curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7/current-tripleo/delorean.repo
    sudo curl -o /etc/yum.repos.d/delorean-current.repo http://trunk.rdoproject.org/liberty/centos7/current/delorean.repo
    sudo sed -i 's/\[delorean\]/\[delorean-current\]/' /etc/yum.repos.d/delorean-current.repo
    sudo curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/liberty/centos7/delorean-deps.repo
fi

# ensure the undercloud package is installed so we can build the undercloud
if ! rpm -q instack-undercloud > /dev/null; then
    sudo yum install -y instack-undercloud
fi

# ensure openvswitch is installed 
if ! rpm -q openvswitch > /dev/null; then
    sudo yum install -y openvswitch
fi

# ensure libvirt is installed 
if ! rpm -q libvirt-daemon-kvm > /dev/null; then
    sudo yum install -y libvirt-daemon-kvm
fi

# ensure that no previous undercloud VMs are running
# and rebuild the bare undercloud VMs
ssh -T -o "StrictHostKeyChecking no" stack@localhost <<EOI
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack 2> /dev/null || echo -n ''
virsh destroy baremetal_0 2> /dev/null || echo -n ''
virsh undefine baremetal_0 2> /dev/null || echo -n ''
virsh destroy baremetal_1 2> /dev/null || echo -n ''
virsh undefine baremetal_1 2> /dev/null || echo -n ''
instack-virt-setup
EOI

# attach undercloud to the underlay network for
# baremetal installations
#if ! ovs-vsctl show | grep brbm; then
#    ovs-vsctl add-port brbm em2
#fi

# let dhcp happen so we can get the ip
# just wait instead of checking until we see an address
# because there may be a previous lease that needs
# to be cleaned up
sleep 5

# get the undercloud ip address
UNDERCLOUD=$(grep instack /var/lib/libvirt/dnsmasq/default.leases | awk '{print $3}' | head -n 1)

# ensure that we can ssh to the undercloud
CNT=10
while ! ssh -T -o "StrictHostKeyChecking no" "root@$UNDERCLOUD" "echo ''" > /dev/null && [ $CNT -gt 0 ]; do
    echo -n "."
    sleep 3
    CNT=CNT-1
done
# TODO fail if CNT=0 

# yum repo, triple-o package and ssh key setup for the undercloud
ssh -T -o "StrictHostKeyChecking no" "root@$UNDERCLOUD" <<EOI
if ! rpm -q epel-release > /dev/null; then
    yum install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7/current-tripleo/delorean.repo
curl -o /etc/yum.repos.d/delorean-current.repo http://trunk.rdoproject.org/liberty/centos7/current/delorean.repo
sed -i 's/\\[delorean\\]/\\[delorean-current\\]/' /etc/yum.repos.d/delorean-current.repo
echo "\\nincludepkgs=diskimage-builder,openstack-heat,instack,instack-undercloud,openstack-ironic,openstack-ironic-inspector,os-cloud-config,python-ironic-inspector-client,python-tripleoclient,tripleo-common,openstack-tripleo-heat-templates,openstack-tripleo-image-elements,openstack-tripleo-puppet-elements,openstack-tuskar-ui-extras,openstack-puppet-modules" >> /etc/yum.repos.d/delorean-current.repo
curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/liberty/centos7/delorean-deps.repo
yum install -y python-tripleoclient
cp /root/.ssh/authorized_keys /home/stack/.ssh/authorized_keys
chown stack:stack /home/stack/.ssh/authorized_keys
EOI

# install undercloud on Undercloud VM
ssh -o "StrictHostKeyChecking no" "stack@$UNDERCLOUD" "openstack undercloud install"

# make a copy of instack VM's definitions, and disk image
# it must be stopped to make a copy of its disk image
ssh -T -o "StrictHostKeyChecking no" stack@localhost <<EOI
echo "Shuttind down instack to take snapshop"
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

echo "\nCopying instack disk image and starting instack VM."
virsh dumpxml baremetal_0 > baremetal_0.xml
virsh dumpxml baremetal_1 > baremetal_1.xml
cp -f /var/lib/libvirt/images/instack.qcow2 .
virsh dumpxml instack > instack.xml
#virsh vol-dumpxml instack.qcow2 --pool default > instack.qcow2.xml
virsh start instack
EOI

# copy off the instack artifacts
echo "Copying instack files to build directory"
scp -o "StrictHostKeyChecking no" stack@localhost:baremetal_0.xml .
scp -o "StrictHostKeyChecking no" stack@localhost:baremetal_1.xml .
scp -o "StrictHostKeyChecking no" stack@localhost:instack.xml .
scp -o "StrictHostKeyChecking no" stack@localhost:instack.qcow2 .


# start the instack VM back up to continue installation
echo "Waiting for instack VM to start"
CNT=10
while ! ping -c 1 "$UNDERCLOUD" > /dev/null  && [ $CNT -gt 0 ]; do
    echo -n "."
    sleep 5
    CNT=CNT-1
done
CNT=10
while ! ssh -T -o "StrictHostKeyChecking no" "root@$UNDERCLOUD" "echo ''" > /dev/null && [ $CNT -gt 0 ]; do
    echo -n "."
    sleep 3
    CNT=CNT-1
done

# inject the already downloaded cloud image so it's not downloaded again
echo "Copying CentOS Cache to instack VM"
ssh -o "StrictHostKeyChecking no" "stack@$UNDERCLOUD" "mkdir .cache"
ssh -T -o "StrictHostKeyChecking no" stack@localhost "scp -r -o 'StrictHostKeyChecking no' /home/stack/.cache/image-create/CentOS-7-x86_64-GenericCloud* \"stack@$UNDERCLOUD\":.cache/"

# build the overcloud images
echo "Building overcloud images"
ssh -tt -o "StrictHostKeyChecking no" "stack@$UNDERCLOUD" "openstack overcloud image build --all"

# copy off the built images
echo "Copying overcloud images"
if [ -f stack ]; then mkdir stack; fi
scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:deploy-ramdisk-ironic.initramfs stack
scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:deploy-ramdisk-ironic.kernel stack
#scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:discovery-ramdisk.initramfs stack
#scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:discovery-ramdisk.kernel stack
scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:fedora-user.qcow2 stack
scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:overcloud-full.initrd stack
scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:overcloud-full.qcow2 stack
scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:overcloud-full.vmlinuz stack
scp -o "StrictHostKeyChecking no" stack@$UNDERCLOUD:instackenv.json instackenv-virt.json
