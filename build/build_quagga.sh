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

set -e

# Install package dependencies
yum -y install automake bison flex libtool make readline-devel \
               texinfo texi2html rpm-build libcap-devel groff net-snmp-devel pam-devel glib2 glib2-devel epel-release spectool \
               wget git gcc-c++ openssl-devel boost-devel gtest
yum -y groupinstall "Development Tools"

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PATCHES_DIR=${SCRIPT_DIR}/patches
#Create Build directory
export QUAGGA_BUILD_FOLDER="${BUILD_DIR}/quagga_build_dir"
function clean(){
  rm -rf ${QUAGGA_BUILD_FOLDER}
}
# clean
mkdir -p ${QUAGGA_BUILD_FOLDER}
pushd ${QUAGGA_BUILD_FOLDER}
rpmbuild=$QUAGGA_BUILD_FOLDER/rpmbuild
mkdir -p $rpmbuild $rpmbuild/SOURCES $rpmbuild/SPECS $rpmbuild/RPMS


function build_thrift(){
  # Build dependency thrift
  rm -rf thrift
  git clone https://git-wip-us.apache.org/repos/asf/thrift.git
  pushd thrift
  git checkout 0.10.0
  wget https://issues.apache.org/jira/secure/attachment/12840511/0002-THRIFT-3986-using-autoreconf-i-fails-because-of-miss.patch
  wget https://issues.apache.org/jira/secure/attachment/12840512/0001-THRIFT-3987-externalise-declaration-of-thrift-server.patch
  patch -p1 < 0002-THRIFT-3986-using-autoreconf-i-fails-because-of-miss.patch
  patch -p1 < 0001-THRIFT-3987-externalise-declaration-of-thrift-server.patch
  autoreconf -i
  ./configure --without-qt4 --without-qt5 --without-csharp --without-java \
    --without-erlang --without-nodejs --without-perl --without-python \
    --without-php --without-php_extension --without-dart --without-ruby \
    --without-haskell --without-go --without-haxe --without-d
  # Hack somehow the testing file of php is not there
  # We will disable php anyhow later on.
  touch lib/php/src/ext/thrift_protocol/run-tests.php
  make dist
  pushd contrib/
  spectool -g -R thrift.spec
  mv ../thrift-*.tar.gz $rpmbuild/SOURCES/
  rpmbuild --define "_topdir $rpmbuild" -ba thrift.spec --define "without_ruby 1" --define "without-php 1"
  popd > /dev/null
  popd > /dev/null
  yum install -y $rpmbuild/RPMS/x86_64/*.rpm
}
#build_thrift

# ZeroMQ package already available for CentOS 7
yum -y install zeromq-4.1.4 zeromq-devel-4.1.4

function build_capnproto(){

  # c-capnproto RPM
  # This is a library for capnproto in C. Not to be confused with
  # the capnproto provided by the repos

  yum -y install capnproto-devel capnproto-libs capnproto

  # Build dependency C-capnproto
  rm -rf c-capnproto
  git clone https://github.com/opensourcerouting/c-capnproto
  pushd c-capnproto
  git checkout 332076e52257
  autoreconf -i
  ./configure --without-gtest
  make dist

  cp $SCRIPT_DIR/rpm_specs/c_capnproto.spec $rpmbuild/SPECS/
  cp c-capnproto-*.tar.gz $rpmbuild/SOURCES/
  rpmbuild --define "_topdir $rpmbuild" -ba $rpmbuild/SPECS/c_capnproto.spec
  popd > /dev/null
  yum install -y $rpmbuild/RPMS/x86_64/*.rpm
  # rski temporary hacks
  mkdir -p /usr/include/c-capnproto
  ln -sf /usr/include/capn.h /usr/include/c-capnproto/
  ln -s /usr/lib64/libcapn.so /usr/lib64/libcapn_c.so
}
#build_capnproto

build_quagga(){
  # Build Quagga
  rm -rf quagga
  git clone https://github.com/6WIND/quagga.git
  pushd quagga > /dev/null
  git checkout quagga_110_mpbgp_capnp
  patch -p1 < ${PATCHES_DIR}/fix_quagga_make_dist.patch
  autoreconf -i
  ./configure --with-zeromq --with-ccapnproto --enable-user=quagga \
    --enable-group=quagga --enable-vty-group=quagga \
    --disable-doc --enable-multipath=64

  # Quagga RPM
  make dist
  cp $SCRIPT_DIR/rpm_specs/quagga.spec $rpmbuild/SPECS/
  cp quagga*.tar.gz $rpmbuild/SOURCES/
  rpmbuild --define "_topdir $rpmbuild" -ba $rpmbuild/SPECS/quagga.spec
  popd > /dev/null
  yum install -y $rpmbuild/RPMS/x86_64/*.rpm
}
#build_quagga

build_zprc(){
  # Build ZPRC
  rm -rf zrpcd
  git clone https://github.com/6WIND/zrpcd.git
  pushd zrpcd > /dev/null
  touch NEWS README
  # we shouldn't have to explicitly do this
  export QUAGGA_CFLAGS='-I/usr/include/quagga/'
  patch -p1 < ${PATCHES_DIR}/fix_zrpcd_make_dist.patch
  autoreconf -i

  # ZRPC RPM
  ./configure --enable-zrpcd \
   --enable-user=quagga --enable-group=quagga \
   --enable-vty-group=quagga
  make dist
  cp zrpcd-*.tar.gz $rpmbuild/SOURCES/
  cp $SCRIPT_DIR/rpm_specs/zrpc.spec $rpmbuild/SPECS/
  rpmbuild --define "_topdir $rpmbuild" -ba $rpmbuild/SPECS/zrpc.spec
  yum install -y $rpmbuild/RPMS/x86_64/*.rpm
}
build_zprc
popd > /dev/null
