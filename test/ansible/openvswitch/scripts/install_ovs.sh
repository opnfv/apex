#!/usr/bin/env bash

mkdir /etc/openvswitch

yum -y localinstall ~ovs/rpmbuild/RPMS/x86_64/openvswitch-2.3.2-1.x86_64.rpm

yum -y install policycoreutils-python

semanage fcontext -a -t openvswitch_rw_t "/etc/openvswitch(/.*)?"
restorecon -Rv /etc/openvswitch

systemctl start openvswitch.service