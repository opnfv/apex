#!/bin/sh
set -e
declare -i CNT

vm_index=4
RDO_RELEASE=kilo
SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null)

# check for dependancy packages
for i in libguestfs-tools; do
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
    sudo curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7-liberty/current-passed-ci/delorean.repo
    sudo curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7-liberty/delorean-deps.repo
    sudo rm -f /etc/yum.repos.d/delorean-current.repo
fi

# install the opendaylight yum repo definition
cat << 'EOF' | sudo tee /etc/yum.repos.d/opendaylight.repo
[opendaylight]
name=OpenDaylight $releasever - $basearch
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-3-candidate/$basearch/os/
enabled=1
gpgcheck=0
EOF

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
# and rebuild the bare undercloud VMs
ssh -T ${SSH_OPTIONS[@]} stack@localhost <<EOI
set -e
virsh destroy instack 2> /dev/null || echo -n ''
virsh undefine instack --remove-all-storage 2> /dev/null || echo -n ''
for i in \$(seq 0 $vm_index); do
  virsh destroy baremetalbrbm_brbm1_\$i 2> /dev/null || echo -n ''
  virsh undefine baremetalbrbm_brbm1_\$i --remove-all-storage 2> /dev/null || echo -n ''
done
NODE_COUNT=5 NODE_CPU=2 NODE_MEM=8192 TESTENV_ARGS="--baremetal-bridge-names 'brbm brbm1'" instack-virt-setup
EOI

# let dhcp happen so we can get the ip
# just wait instead of checking until we see an address
# because there may be a previous lease that needs
# to be cleaned up
sleep 5

# get the undercloud ip address
UNDERCLOUD=$(grep instack /var/lib/libvirt/dnsmasq/default.leases | awk '{print $3}' | head -n 1)

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
yum install -y python-tripleoclient
cp /root/.ssh/authorized_keys /home/stack/.ssh/authorized_keys
chown stack:stack /home/stack/.ssh/authorized_keys
EOI

# install undercloud on Undercloud VM
ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "openstack undercloud install"

# copy instackenv file for future virt deployments
if [ ! -d stack ]; then mkdir stack; fi
scp ${SSH_OPTIONS[@]} stack@$UNDERCLOUD:instackenv.json stack/instackenv.json

# Clean cache to reduce the images size
ssh -T ${SSH_OPTIONS[@]} "root@$UNDERCLOUD" "yum clean all"

# make a copy of instack VM's definitions, and disk image
# it must be stopped to make a copy of its disk image
ssh -T ${SSH_OPTIONS[@]} stack@localhost <<EOI
set -e
echo "Shutting down instack to take snapshot"
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
  virsh dumpxml baremetalbrbm_brbm1_\$i | awk '/model type='\''virtio'\''/{c++;if(c==2){sub("model type='\''virtio'\''","model type='\''rtl8139'\''");c=0}}1' > baremetalbrbm_brbm1_\$i.xml
done

virsh dumpxml instack > instack.xml
virsh net-dumpxml brbm > brbm-net.xml
virsh net-dumpxml brbm1 > brbm1-net.xml
virsh pool-dumpxml default > default-pool.xml
EOI

# copy off the instack artifacts
echo "Copying instack files to build directory"
for i in $(seq 0 $vm_index); do
  scp ${SSH_OPTIONS[@]} stack@localhost:baremetalbrbm_brbm1_${i}.xml .
done

scp ${SSH_OPTIONS[@]} stack@localhost:instack.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:brbm-net.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:brbm1-net.xml .
scp ${SSH_OPTIONS[@]} stack@localhost:default-pool.xml .

# copy the instack disk image for inclusion in artifacts
sudo cp /var/lib/libvirt/images/instack.qcow2 ./instack.qcow2

#sudo chown $(whoami):$(whoami) ./instack.qcow2_
#virt-sparsify --check-tmpdir=fail ./instack.qcow2_ ./instack.qcow2
#rm -f ./instack.qcow2_

# pull down the the built images
echo "Copying overcloud resources"
IMAGES="deploy-ramdisk-ironic.initramfs deploy-ramdisk-ironic.kernel"
IMAGES+=" ironic-python-agent.initramfs ironic-python-agent.kernel ironic-python-agent.vmlinuz"
IMAGES+=" overcloud-full.initrd overcloud-full.qcow2  overcloud-full.vmlinuz"

for i in $IMAGES; do
  # download prebuilt images from RDO Project
  curl https://repos.fedorapeople.org/repos/openstack-m/rdo-images-centos-liberty/$i -z stack/$i -o stack/$i --verbose --silent --location
done

#Adding OpenDaylight to overcloud
pushd stack
cp overcloud-full.qcow2 overcloud-full-odl.qcow2
for i in opendaylight python-networking-odl; do
    yumdownloader $i
    if rpmfile=$(ls -r $i*); then
        rpmfile=$(echo $rpmfile | head -n1)
        LIBGUESTFS_BACKEND=direct virt-customize --upload $rpmfile:/tmp --install /tmp/$rpmfile -a overcloud-full-odl.qcow2
    else
        echo "Cannot install $i into overcloud-full image."
	exit 1
    fi
done
rm -rf puppet-opendaylight
git clone https://github.com/dfarrell07/puppet-opendaylight
pushd puppet-opendaylight
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ../puppet-opendaylight.tar.gz
popd
LIBGUESTFS_BACKEND=direct virt-customize --upload puppet-opendaylight.tar.gz:/etc/puppet/modules/ --run-command "cd /etc/puppet/modules/; tar xzf puppet-opendaylight.tar.gz" -a overcloud-full-odl.qcow2
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
  virsh destroy baremetalbrbm_brbm1_\$i 2> /dev/null || echo -n ''
  virsh undefine baremetalbrbm_brbm1_\$i --remove-all-storage 2> /dev/null || echo -n ''
done
EOI

