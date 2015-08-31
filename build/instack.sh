#!/bin/sh
set -e
declare -i CNT

RDO_RELEASE=liberty

if ! id stack > /dev/null; then
    if [ id -u == '0' ]; then
        useradd stack;
        echo 'stack ALL=(root) NOPASSWD:ALL' | sudo tee -a /etc/sudoers.d/stack
        echo 'Defaults:stack !requiretty' | sudo tee -a /etc/sudoers.d/stack
        chmod 0440 /etc/sudoers.d/stack
        echo 'Added user stack'
    else
        echo 'Stack user does not exist'
        exit 1
    fi
fi

ssh -T -o "StrictHostKeyChecking no" stack@localhost "rm -f instack*.qcow2"

if ! rpm -q epel-release > /dev/null; then
    yum install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

if ! rpm -q rdo-release > /dev/null && [ "$1" != "-trunk" ]; then
    yum install -y https://rdoproject.org/repos/openstack-${RDO_RELEASE}/rdo-release-${RDO_RELEASE}.rpm
    rm -rf /etc/yum.repos.d/delorean.repo
    rm -rf /etc/yum.repos.d/delorean-current.repo
elif [ "$1" == "-trunk" ]; then
    yum -y install yum-plugin-priorities
    yum-config-manager --disable openstack-${RDO_RELEASE}
    curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7/current-tripleo/delorean.repo
    curl -o /etc/yum.repos.d/delorean-current.repo http://trunk.rdoproject.org/centos7/current/delorean.repo
    sed -i 's/\[delorean\]/\[delorean-current\]/' /etc/yum.repos.d/delorean-current.repo
    #curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7/delorean-deps.repo
fi

#if ! [ -a /etc/yum.repos.d/rdo-management-trunk.repo ]; then
#    curl -o /etc/yum.repos.d/rdo-management-trunk.repo http://trunk-mgt.rdoproject.org/centos-kilo/current-passed-ci/delorean-rdo-management.repo
#fi

if ! rpm -q instack-undercloud > /dev/null; then
    yum install -y instack-undercloud
fi

ssh -T -o "StrictHostKeyChecking no" stack@localhost <<EOI
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack 2> /dev/null || echo -n ''
virsh destroy baremetal_0 2> /dev/null || echo -n ''
virsh undefine baremetal_0 2> /dev/null || echo -n ''
virsh destroy baremetal_1 2> /dev/null || echo -n ''
virsh undefine baremetal_1 2> /dev/null || echo -n ''
instack-virt-setup
EOI

#if ! ovs-vsctl show | grep brbm; then
#    ovs-vsctl add-port brbm em2
#fi
#cp /home/stack/.ssh/id_rsa* /root/.ssh/

# let dhcp happen so we can get the ip
# just wait instead of checking until we see an address
# because there may be a previous lease that needs
# to be cleaned up
sleep 5

UNDERCLOUD=$(grep instack /var/lib/libvirt/dnsmasq/default.leases | awk '{print $3}' | head -n 1)

CNT=10
while ! ssh -T -o "StrictHostKeyChecking no" "root@$UNDERCLOUD" "echo ''" > /dev/null && [ $CNT -gt 0 ]; do
    echo -n "."
    sleep 3
    CNT=CNT-1
done

#ssh -T -o "StrictHostKeyChecking no" "root@$UNDERCLOUD" <<EOI
#if ! rpm -q rdo-release > /dev/null; then
#    yum install -y https://rdoproject.org/repos/openstack-kilo/rdo-release-kilo.rpm
#fi

ssh -T -o "StrictHostKeyChecking no" "root@$UNDERCLOUD" <<EOI
if ! rpm -q epel-release > /dev/null; then
    yum install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7/current-tripleo/delorean.repo
curl -o /etc/yum.repos.d/delorean-current.repo http://trunk.rdoproject.org/centos7/current/delorean.repo
sed -i 's/\\[delorean\\]/\\[delorean-current\\]/' /etc/yum.repos.d/delorean-current.repo
echo "\\nincludepkgs=diskimage-builder,openstack-heat,instack,instack-undercloud,openstack-ironic,openstack-ironic-inspector,os-cloud-config,python-ironic-inspector-client,python-tripleoclient,tripleo-common,openstack-tripleo-heat-templates,openstack-tripleo-image-elements,openstack-tripleo-puppet-elements,openstack-tuskar-ui-extras,openstack-puppet-modules" >> /etc/yum.repos.d/delorean-current.repo
curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7/delorean-deps.repo
yum install -y python-tripleoclient
cp /root/.ssh/authorized_keys /home/stack/.ssh/authorized_keys
chown stack:stack /home/stack/.ssh/authorized_keys
EOI

ssh -o "StrictHostKeyChecking no" "stack@$UNDERCLOUD" "openstack undercloud install"
#ssh -T -o "StrictHostKeyChecking no" stack@$UNDERCLOUD <<EOI
#echo "Running undercloud install"
#openstack undercloud install
#dontexit=\$(openstack undercloud install)
#openstack undercloud install && sudo halt -p
#EOI
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

echo "Copying instack files to build directory"
scp -o "StrictHostKeyChecking no" stack@localhost:baremetal_0.xml .
scp -o "StrictHostKeyChecking no" stack@localhost:baremetal_1.xml .
scp -o "StrictHostKeyChecking no" stack@localhost:instack.xml .
scp -o "StrictHostKeyChecking no" stack@localhost:instack.qcow2 .


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

echo "Copying CentOS Cache to instack VM"
ssh -o "StrictHostKeyChecking no" "stack@$UNDERCLOUD" "mkdir .cache"
ssh -T -o "StrictHostKeyChecking no" stack@localhost "scp -r -o 'StrictHostKeyChecking no' /home/stack/.cache/image-create/CentOS-7-x86_64-GenericCloud* \"stack@$UNDERCLOUD\":.cache/"

echo "Building overcloud images"
ssh -tt -o "StrictHostKeyChecking no" "stack@$UNDERCLOUD" "openstack overcloud image build --all"

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
