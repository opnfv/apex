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

./boot.sh
libtoolize --force
aclocal
autoheader
automake --force-missing --add-missing
autoconf
./configure
make rpm-fedora RPMBUILD_OPT="\"-D kversion `rpm -q kernel | rpmdev-sort  | tail -n -1 | sed  's/^kernel-//'`\" --without check"
make rpm-fedora-kmod RPMBUILD_OPT="\"-D kversion `rpm -q kernel | rpmdev-sort  | tail -n -1 | sed  's/^kernel-//'`\""