#!/bin/sh
set -e
declare -i CNT

rdo_images_uri=https://ci.centos.org/artifacts/rdo/images/liberty/delorean/stable

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

# install the opendaylight yum repo definition
cat << 'EOF' | sudo tee /etc/yum.repos.d/opendaylight.repo
[opendaylight]
name=OpenDaylight $releasever - $basearch
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-33-release/$basearch/os/
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
  UNDERCLOUD=$(arp -e | grep ${instack_mac} | awk {'print $1'})

  if [ -z "$UNDERCLOUD" ]; then
    echo "\n\nNever got IP for Instack. Can Not Continue."
    exit 1
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
    wget -nv -O stack/$i $rdo_images_uri/$i
    #else
    #  curl $rdo_images_uri/$i -o stack/$i --verbose --silent --location
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

LIBGUESTFS_BACKEND=direct virt-customize --install $PACKAGES -a instack.qcow2
popd


#Adding OpenDaylight to overcloud
pushd stack
# make a copy of the cached overcloud-full image
cp overcloud-full.qcow2 overcloud-full-odl.qcow2

# remove unnessesary packages and install nessesary packages
LIBGUESTFS_BACKEND=direct virt-customize --run-command "yum remove -y openstack-neutron-openvswitch" \
    --upload /etc/yum.repos.d/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --install opendaylight,python-networking-odl -a overcloud-full-odl.qcow2

## WORK AROUND
## when OpenDaylight lands in upstream RDO manager this can be removed

# upload the opendaylight puppet module
rm -rf puppet-opendaylight
git clone -b 2.2.0 https://github.com/dfarrell07/puppet-opendaylight
pushd puppet-opendaylight
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ../puppet-opendaylight.tar.gz
popd
LIBGUESTFS_BACKEND=direct virt-customize --upload puppet-opendaylight.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-opendaylight.tar.gz" -a overcloud-full-odl.qcow2

# Patch in OpenDaylight installation and configuration
LIBGUESTFS_BACKEND=direct virt-customize --upload ../opendaylight-tripleo-heat-templates.patch:/tmp \
                                         --run-command "cd /usr/share/openstack-tripleo-heat-templates/ && patch -Np1 < /tmp/opendaylight-tripleo-heat-templates.patch" \
                                         -a instack.qcow2
LIBGUESTFS_BACKEND=direct virt-customize --upload ../opendaylight-puppet-neutron.patch:/tmp \
                                         --run-command "cd /etc/puppet/modules/neutron && patch -Np1 < /tmp/opendaylight-puppet-neutron.patch" \
                                         -a overcloud-full-odl.qcow2
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

