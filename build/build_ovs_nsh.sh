#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2016 Tim Rozet (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -e

yum -y install  rpm-build autoconf automake libtool systemd-units openssl openssl-devel python python-twisted-core python-zope-interface python-six desktop-file-utils groff graphviz  procps-ng libcap-ng libcap-ng-devel PyQt4 selinux-policy-devel kernel-devel kernel-headers kernel-tools
./boot.sh
libtoolize --force
aclocal
autoheader
automake --force-missing --add-missing
autoconf
./configure
yum -y install rpmdevtools
# hack due to build pulling in kernel vxlan header
kernel_vxlan="/usr/src/kernels/$(rpm -q kernel-headers | grep -Eo '[0-9].*x86_64')/include/net/vxlan.h"
sed -i '/struct vxlan_metadata {/a\        u32             gpe;' $kernel_vxlan
make rpm-fedora RPMBUILD_OPT="\"-D kversion `rpm -q kernel | rpmdev-sort  | tail -n -1 | sed  's/^kernel-//'`\" --without check"
make rpm-fedora-kmod RPMBUILD_OPT="\"-D kversion `rpm -q kernel | rpmdev-sort  | tail -n -1 | sed  's/^kernel-//'`\""
