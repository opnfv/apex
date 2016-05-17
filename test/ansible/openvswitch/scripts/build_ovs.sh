#!/usr/bin/env bash

adduser ovs
#su - ovs
#whoami >> ~/ovs.out

runuser -l ovs -c 'mkdir -p ~ovs/rpmbuild/SOURCES'

runuser -l ovs -c 'wget http://openvswitch.org/releases/openvswitch-2.3.2.tar.gz'
runuser -l ovs -c 'cp openvswitch-2.3.2.tar.gz ~ovs'
echo 'Downloaded openvswitch-2.3.2.tar.gz' >> ~/ovs.out

runuser -l ovs -c 'cp ~ovs/openvswitch-2.3.2.tar.gz ~ovs/rpmbuild/SOURCES/'
echo 'Copied ovs tar to ~ovs/rpmbuild/SOURCES' >> ~/ovs.out

cd ~ovs
runuser -l ovs -c 'tar xfz openvswitch-2.3.2.tar.gz'
echo 'Extracted ovs tar' >> ~/ovs.out

sed 's/openvswitch-kmod, //g' ~ovs/openvswitch-2.3.2/rhel/openvswitch.spec > ~ovs/openvswitch-2.3.2/rhel/openvswitch_no_kmod.spec

chown ovs:ovs ~ovs/openvswitch-2.3.2/rhel/openvswitch_no_kmod.spec

runuser -l ovs -c 'rpmbuild -bb --nocheck openvswitch-2.3.2/rhel/openvswitch_no_kmod.spec'