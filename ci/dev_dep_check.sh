#!/bin/sh
##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# This script makes sure deploy deps are installed when not relying on RPM

set -e

# check for rdo-release
if ! rpm -q rdo-release > /dev/null; then
    sudo yum remove rdo-release
fi

# make sure rdo release
if ! sudo yum install -y  https://repos.fedorapeople.org/repos/openstack/openstack-newton/rdo-release-newton-5.noarch.rpm; then
    echo "Failed to install RDO Release package..."
    exit 1
fi

# update ipxe-roms-qemu
if ! sudo yum update -y ipxe-roms-qemu; then
    echo "Failed to update ipxe-roms-qemu package..."
    exit 1
fi

# check for other packages
for i in epel-release python34-PyYAML openvswitch openstack-tripleo libguestfs libguestfs-tools-c libvirt-python python2-oslo-config python2-debtcollector python34-devel libxslt-devel libxml2-devel; do
# Make sure deploy deps are installed
    if ! rpm -q $i > /dev/null; then
        if ! sudo yum install -y $i; then
            echo "Failed to install $i package..."
            exit 1
        fi
    fi
done

# install pip dependencies
easy_install-3.4 pip
sudo pip3 install python-ipmi

# Make sure jinja2 is installed
easy_install-3.4 jinja2

# TODO(cgoncalves): remove once congress RPM is downloaded from upstream
easy_install-3.4 tox

# Required packages to redirect stdin with virt-customize
if ! sudo yum -y install libguestfs libguestfs-tools libguestfs-tools-c supermin supermin5 supermin-helper perl-Sys-Guestfs python-libguestfs; then
    echo "Failed to install supermin/libguestfs packages..."
    exit 1
fi
