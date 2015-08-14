#!/bin/sh 
set -e
if ! id stack > /dev/null; then
    useradd stack;
    echo 'stack ALL=(root) NOPASSWD:ALL' | sudo tee -a /etc/sudoers.d/stack
    echo 'Defaults:stack !requiretty' | sudo tee -a /etc/sudoers.d/stack
    chmod 0440 /etc/sudoers.d/stack
    echo 'Added user stack'
fi

if ! rpm -q epel-release > /dev/null; then
    yum install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

if ! rpm -q rdo-release > /dev/null; then
    yum install -y https://rdoproject.org/repos/openstack-kilo/rdo-release-kilo.rpm
fi

if ! [ -a /etc/yum.repos.d/rdo-management-trunk.repo ]; then
    curl -o /etc/yum.repos.d/rdo-management-trunk.repo http://trunk-mgt.rdoproject.org/centos-kilo/current-passed-ci/delorean-rdo-management.repo
fi

if ! rpm -q instack-undercloud > /dev/null; then
    yum install -y instack-undercloud
fi

sudo -u stack -- sh -c 'cd; instack-virt-setup'
#if ! ovs-vsctl show | grep brbm; then
#    ovs-vsctl add-port brbm em2
#fi
cp /home/stack/.ssh/id_rsa* /root/.ssh/
UNDERCLOUD=$(virsh net-dhcp-leases default | grep instack | awk '{print $5}' | awk -F '/' '{print $1}')

ssh -T -o "StrictHostKeyChecking no" root@$UNDERCLOUD <<EOI
if ! rpm -q rdo-release > /dev/null; then
    yum install -y https://rdoproject.org/repos/openstack-kilo/rdo-release-kilo.rpm
fi

if ! [ -a /etc/yum.repos.d/rdo-management-trunk.repo ]; then
    curl -o /etc/yum.repos.d/rdo-management-trunk.repo http://trunk-mgt.rdoproject.org/centos-kilo/current-passed-ci/delorean-rdo-management.repo
fi

yum install -y python-rdomanager-oscplugin
cp /root/.ssh/authorized_keys /home/stack/.ssh/authorized_keys
chown stack:stack /home/stack/.ssh/authorized_keys
EOI

ssh -o "StrictHostKeyChecking no" stack@$UNDERCLOUD "openstack undercloud install"
#ssh -T -o "StrictHostKeyChecking no" stack@$UNDERCLOUD <<EOI
#echo "Running undercloud install"
#openstack undercloud install
#dontexit=\$(openstack undercloud install)
#openstack undercloud install && sudo halt -p
#EOI
echo "Shuttind down instack to take snapshop"
virsh shutdown instack

echo "Waiting for instack VM to shutdown"
while virsh list | grep instack; do
    echo -n "."
    sleep 5
done

echo "Copying instack disk image and starting instack VM."
cp -f /var/lib/libvirt/images/instack.qcow2 .
virsh dumpxml instack > instack.xml
virsh vol-dumpxml instack.qcow2 --pool default > instack.qcow2.xml
virsh start instack

echo "Waiting for instack VM to start"
while ! ping -c 1 $UNDERCLOUD > /dev/null; do
    echo -n "."
    sleep 5
done
while ! ssh -T -o "StrictHostKeyChecking no" root@$UNDERCLOUD "echo ''" > /dev/null; do
    echo -n "."
    sleep 3
done

echo "Copying CentOS Cache to instack VM"
ssh -o "StrictHostKeyChecking no" stack@$UNDERCLOUD "mkdir .cache"
scp -r /home/stack/.cache/image-create/CentOS-7-x86_64-GenericCloud* stack@$UNDERCLOUD:.cache/

echo "Building overcloud images"
ssh -tt -o "StrictHostKeyChecking no" stack@$UNDERCLOUD "openstack overcloud image build --all"

echo "Copying overcloud images"
mkdir stack
scp stack@$UNDERCLOUD:deploy-ramdisk-ironic.initramfs stack
scp stack@$UNDERCLOUD:deploy-ramdisk-ironic.kernel stack
scp stack@$UNDERCLOUD:discovery-ramdisk.initramfs stack
scp stack@$UNDERCLOUD:discovery-ramdisk.kernel stack
scp stack@$UNDERCLOUD:fedora-user.qcow2 stack
scp stack@$UNDERCLOUD:overcloud-full.initrd stack
scp stack@$UNDERCLOUD:overcloud-full.qcow2 stack
scp stack@$UNDERCLOUD:overcloud-full.vmlinuz stack
