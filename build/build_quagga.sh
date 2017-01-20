#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2017 Tim Rozet (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Builds Quagga, Zebra and other dependency RPMs for CentOS 7

set -eux

# Install package dependencies
yum -y install automake bison flex g++ git libboost1.55-all-dev libevent-dev libssl-dev libtool make pkg-config readline-devel \
texinfo texi2html rpm-build libcap-devel groff net-snmp-devel pam-devel glib2 glib2-devel epel-release
yum -y install spectool

yum -y install capnproto-devel capnproto-libs capnproto

# Build dependency thrift
git clone https://src.fedoraproject.org/git/rpms/thrift.git
pushd thrift > /dev/null
git checkout epel7

wget https://issues.apache.org/jira/secure/attachment/12840511/0002-THRIFT-3986-using-autoreconf-i-fails-because-of-miss.patch
wget https://issues.apache.org/jira/secure/attachment/12840512/0001-THRIFT-3987-externalise-declaration-of-thrift-server.patch

git apply ../thrift-spec-apply-patches.patch
# get the sources described in the thrift file
spectool -g -R thrift.spec
yum-builddep thrift.spec -y
rpmbuild --define "_topdir `pwd`/rpmbuild" -ba thrift.spec

popd > /dev/null

# Build dependency ZeroMQ
git clone https://github.com/zeromq/zeromq4-1.git
pushd zeromq4-1 > /dev/null
git checkout 56b71af22db3
autoreconf -i
./configure --without-libsodium --prefix=/opt/quagga
make
make install
popd > /dev/null

# ZeroMQ package already available for CentOS 7
yum -y install zeromq-4.1.4-5 zeromq-devel-4.1.4-5

# Build dependency C-capnproto
git clone https://github.com/opensourcerouting/c-capnproto
pushd c-capnproto > /dev/null
git checkout 332076e52257
autoreconf -i
./configure --prefix=/opt/quagga --without-gtest
make
mkdir /opt/quagga/lib -p
mkdir /opt/quagga/include/c-capnproto -p
cp capn.h /opt/quagga/include/c-capnproto/.
cp .libs/libcapn.so.1.0.0 .libs/libcapn_c.so.1.0.0
ln -s .libs/libcapn_c.so.1.0.0 .libs/libcapn_c.so
cp .libs/libcapn.so.1.0.0 /opt/quagga/lib/libcapn_c.so.1.0.0
ln -s /opt/quagga/lib/libcapn_c.so.1.0.0 /opt/quagga/lib/libcapn_c.so

# capnproto RPM
# this is hack.  capnproto package already exists so we install that.
# however, the version being used to build custom quagga has a different
# version and kmod ver.  So we workaround by building an additional rpm to
# install the kmod that was used to build quagga
yum -y install capnproto-devel capnproto-libs capnproto

# build rpm hacked lib
./configure
make dist
mkdir rpmbuild
mkdir rpmbuild/SOURCES
mkdir rpmbuild/SPECS
mkdir rpmbuild/RPMS
cp /root/libcapn.spec rpmbuild/SPECS/
cp c-capnproto-0.1.tar.gz rpmbuild/SOURCES/
rpmbuild --define "_topdir `pwd`/rpmbuild" -ba rpmbuild/SPECS/quagga.spec
yum -y install rpmbuild/RPMS/x86_64/*.rpm
popd > /dev/null

# Build Quagga
git clone https://github.com/6WIND/quagga.git
pushd quagga > /dev/null
git checkout quagga_110_mpbgp_capnp
export ZEROMQ_CFLAGS="-I/root/zeromq4-1/include"
export ZEROMQ_LIBS="-L/root/zeromq4-1/.libs/ -lzmq"
export CAPN_C_CFLAGS='-I/root/c-capnproto/ -I/opt/quagga/include -I/opt/quagga/include/quagga -I/root/quagga_int/quagga/lib/'
export CAPN_C_LIBS='-L/root/c-capnproto/.libs/ -lcapn_c'
autoreconf -i
LIBS='-L/root/zeromq4-1/.libs -L/root/c-capnproto/.libs/ -L/opt/quagga/lib' \
./configure --with-zeromq --with-ccapnproto --prefix=/opt/quagga --enable-user=quagga \
--enable-group=quagga --enable-vty-group=quagga --localstatedir=/opt/quagga/var/run/quagga \
--disable-doc --enable-multipath=64
cp /opt/quagga/include/c-capnproto/capn.h lib/
mkdir -p /root/quagga/bgpd/c-capnproto/
cp lib/capn.h /root/quagga/bgpd/c-capnproto/
make
make install

# Quagga RPM
./bootstrap.sh
make dist
mkdir rpmbuild
mkdir rpmbuild/SOURCES
mkdir rpmbuild/SPECS
mkdir rpmbuild/RPMS
cp /root/quagga.spec rpmbuild/SPECS/
cp quagga*.tar.gz rpmbuild/SOURCES/
LIBS='-L/root/zeromq4-1/.libs -L/root/c-capnproto/.libs/ -L/opt/quagga/lib' \
rpmbuild --define "_topdir `pwd`/rpmbuild" -ba rpmbuild/SPECS/quagga.spec
yum -y install rpmbuild/RPMS/x86_64/*.rpm
popd > /dev/null

# Build ZPRC
export THRIFT_CFLAGS="-I/root/quagga_int/thrift/lib/c_glib/src/ -I/opt/quagga/include -I/root/thrift/lib/c_glib/src/thrift/c_glib/"
export THRIFT_LIBS="-L/root/thrift/lib/c_glib/.libs/ -lthrift_c_glib"
export QUAGGA_CFLAGS='-I/root/quagga/lib/'
export QUAGGA_LIBS='-L/root/quagga/lib/.libs -lzebra'
git clone https://github.com/6WIND/zrpcd.git
pushd zrpcd > /dev/null
touch NEWS README
autoreconf -i
LIBS='-L/root/zeromq4-1/.libs -L/root/c-capnproto/.libs/ -L/root/thrift/lib/c_glib/.libs/ \
 -L/root/quagga/lib/.libs -L/opt/quagga/lib' ./configure --enable-zrpcd --prefix=/opt/quagga \
 --enable-user=quagga --enable-group=quagga \
 --enable-vty-group=quagga --localstatedir=/opt/quagga/var/run/quagga
make
make install
mkdir /opt/quagga/etc/init.d -p
cp pkgsrc/zrpcd.ubuntu /opt/quagga/etc/init.d/zrpcd
echo "hostname bgpd" >> /opt/quagga/etc/bgpd.conf
echo "password sdncbgpc" >> /opt/quagga/etc/bgpd.conf
echo "service advanced-vty" >> /opt/quagga/etc/bgpd.conf
echo "log stdout" >> /opt/quagga/etc/bgpd.conf
echo "line vty" >> /opt/quagga/etc/bgpd.conf
echo " exec-timeout 0 0 " >> /opt/quagga/etc/bgpd.conf
echo "debug bgp " >> /opt/quagga/etc/bgpd.conf
echo "debug bgp updates" >> /opt/quagga/etc/bgpd.conf
echo "debug bgp events" >> /opt/quagga/etc/bgpd.conf
echo "debug bgp fsm" >> /opt/quagga/etc/bgpd.conf
chmod +x /opt/quagga/etc/init.d/zrpcd


# ZRPC RPM
LIBS='-L/root/zeromq4-1/.libs -L/root/c-capnproto/.libs/ -L/root/thrift/lib/c_glib/.libs/ \
 -L/root/quagga/lib/.libs -L/opt/quagga/lib' ./configure --enable-zrpcd \
 --enable-user=quagga --enable-group=quagga \
 --enable-vty-group=quagga
make dist
mkdir rpmbuild
mkdir rpmbuild/SOURCES
mkdir rpmbuild/SPECS
mkdir rpmbuild/RPMS
cp zrpcd-*.tar.gz rpmbuild/SOURCES/
LIBS='-L/root/zeromq4-1/.libs -L/root/c-capnproto/.libs/ -L/root/thrift/lib/c_glib/.libs/ \
 -L/root/quagga/lib/.libs -L/opt/quagga/lib' \
rpmbuild --define "_topdir `pwd`/rpmbuild" -ba rpmbuild/SPECS/zrpc.spec
