#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2017 Tim Rozet (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -xe

ARTIFACT=None

# Builds Quagga, Zebra and other dependency RPMs for CentOS 7
# Install package dependencies
install_quagga_build_deps() {
  sudo yum -y install automake bison flex libtool make readline-devel \
               texinfo texi2html rpm-build libcap-devel groff net-snmp-devel pam-devel glib2 glib2-devel epel-release spectool \
               wget git gcc-c++ openssl-devel boost-devel boost-static gtest zeromq-4.1.4 zeromq-devel-4.1.4 \
               capnproto-devel capnproto-libs capnproto
  sudo yum -y groupinstall "Development Tools"
}

display_usage ()
{
cat << EOF
$0 Builds Quagga/ZRPC and Dependency RPMs

usage: $0 [ [-a | --artifact] artifact ]

OPTIONS:
  -a artifact to build (thrift, capnproto, quagga, zrpc). Default: All artifacts.
  -c clean all build directories
  -h help, prints this help text

Example:
build_quagga.sh -a thrift
EOF
}

parse_cmdline() {
  while [ "${1:0:1}" = "-" ]
  do
    case "$1" in
        -h|--help)
                display_usage
                exit 0
            ;;
        -a|--artifact)
                ARTIFACT=${2}
                shift 2
            ;;
        -c|--clean)
                CLEAN="True"
                shift 1
            ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done

}

# Removes build directory folder and re-creates RPM DIRs to use
function quagga_clean(){
  rm -rf ${QUAGGA_BUILD_DIR}
  sudo yum remove -y zrpc* quagga* thrift* c-capnproto*
}

# Build Thrift RPM
function build_thrift(){
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
}

# c-capnproto RPM
# This is a library for capnproto in C. Not to be confused with
# the capnproto provided by the repos
function build_capnproto(){
  rm -rf c-capnproto
  git clone https://github.com/opensourcerouting/c-capnproto
  pushd c-capnproto
  git checkout 332076e52257
  autoreconf -i
  ./configure --without-gtest
  make dist

  cp ${BUILD_ROOT}/rpm_specs/c_capnproto.spec $rpmbuild/SPECS/
  cp c-capnproto-*.tar.gz $rpmbuild/SOURCES/
  rpmbuild --define "_topdir $rpmbuild" -ba $rpmbuild/SPECS/c_capnproto.spec
  popd > /dev/null
}

build_quagga(){
  # Build Quagga
  rm -rf quagga
  sudo yum -y install $rpmbuild/RPMS/x86_64/*.rpm
  git clone https://github.com/6WIND/quagga.git
  pushd quagga > /dev/null
  # checkout the parent of the bellow patch.
  # Once the issue addressed by the patch is fixed
  # these two lines can be removed.
  git checkout 95bb0f4a
  patch -p1 < ${PATCHES_DIR}/fix_quagga_make_dist.patch
  autoreconf -i
  ./configure --with-zeromq --with-ccapnproto --enable-user=quagga \
    --enable-group=quagga --enable-vty-group=quagga \
    --disable-doc --enable-multipath=64

  # Quagga RPM
  make dist
  cp ${BUILD_ROOT}/rpm_specs/quagga.spec $rpmbuild/SPECS/
  cp quagga*.tar.gz $rpmbuild/SOURCES/
  cat > $rpmbuild/SOURCES/bgpd.conf <<EOF
hostname bgpd
password sdncbgpc
service advanced-vty
log stdout
line vty
 exec-timeout 0 0
debug bgp
debug bgp updates
debug bgp events
debug bgp fsm
EOF
  rpmbuild --define "_topdir $rpmbuild" -ba $rpmbuild/SPECS/quagga.spec
  popd > /dev/null
}

# Build ZPRC
build_zrpc(){
  sudo yum -y install $rpmbuild/RPMS/x86_64/*.rpm
  rm -rf zrpcd
  git clone https://github.com/6WIND/zrpcd.git
  pushd zrpcd > /dev/null
  touch NEWS README
  export QUAGGA_CFLAGS='-I/usr/include/quagga/'
  # checkout the parent of the bellow patch.
  # Once the issue addressed by the patch is fixed
  # these two lines can be removed.
  git checkout 9bd1ee8e
  patch -p1 < ${PATCHES_DIR}/fix_zrpcd_make_dist.patch
  patch -p1 < ${PATCHES_DIR}/zrpcd_hardcoded_paths.patch
  autoreconf -i

  # ZRPC RPM
  ./configure --enable-zrpcd \
   --enable-user=quagga --enable-group=quagga \
   --enable-vty-group=quagga
  make dist

  cat > $rpmbuild/SOURCES/zrpcd.service <<EOF
[Unit]
Description=ZRPC daemon for quagga
After=network.service

[Service]
ExecStart=/usr/sbin/zrpcd
Type=forking
PIDFile=/var/run/zrpcd.pid
Restart=on-failure

[Install]
WantedBy=default.target
EOF
  cp zrpcd-*.tar.gz $rpmbuild/SOURCES/
  cp ${BUILD_ROOT}/rpm_specs/zrpc.spec $rpmbuild/SPECS/
  rpmbuild --define "_topdir $rpmbuild" -ba $rpmbuild/SPECS/zrpc.spec
}

# Main
parse_cmdline "$@"

# Check env vars
if [ -z "$QUAGGA_BUILD_DIR" ]; then
  echo "ERROR: You must set QUAGGA_BUILD_DIR env variable as the location to build!"
  exit 1
elif [ -z "$QUAGGA_RPMS_DIR" ]; then
  echo "WARN: QUAGGA_RPMS_DIR env var is not set, will default to QUAGGA_BUILD_DIR/rpmbuild"
  rpmbuild=${QUAGGA_BUILD_DIR}/rpmbuild
else
  rpmbuild=${QUAGGA_RPMS_DIR}
fi

if [ -z "$BUILD_ROOT" ]; then
  echo "WARN: BUILD_ROOT env var not set, will default to $(pwd)"
  BUILD_ROOT=$(pwd)
fi

if [ -z "$PATCHES_DIR" ]; then
  echo "WARN: PATCHES_DIR env var not set, will default to ${BUILD_ROOT}/patches"
  PATCHES_DIR=${BUILD_ROOT}/patches
fi

if [ -n "$CLEAN" ]; then
  quagga_clean
fi

install_quagga_build_deps

mkdir -p ${QUAGGA_BUILD_DIR}
mkdir -p $rpmbuild $rpmbuild/SOURCES $rpmbuild/SPECS $rpmbuild/RPMS
pushd $QUAGGA_BUILD_DIR > /dev/null

case "$ARTIFACT" in
        thrift)
          build_thrift
          ;;
        capnproto)
          build_capnproto
          ;;
        quagga)
          build_quagga
          ;;
        zrpc)
          build_zrpc
          ;;
        *)
          build_thrift
          build_capnproto
          build_quagga
          build_zprc
          ;;
esac

popd > /dev/null
