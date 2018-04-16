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

rdo_action="update"

# check for rdo-release
if ! rpm -q rdo-release > /dev/null; then
    rdo_action="install"
fi

# make sure rdo release
if ! sudo yum $rdo_action -y  https://www.rdoproject.org/repos/rdo-release.rpm; then
    echo "Failed to $rdo_action RDO Release package..."
    exit 1
fi

# update ipxe-roms-qemu
if ! sudo yum update -y ipxe-roms-qemu; then
    echo "Failed to update ipxe-roms-qemu package..."
    exit 1
fi

# check for other packages
for i in epel-release openvswitch libguestfs \
         libguestfs-tools-c libvirt-python libxslt-devel \
         libxml2-devel ansible python34-pip python-pip \
         rpm-build wget libvirt ntpdate; do
    # Make sure deploy deps are installed
    if ! rpm -q $i > /dev/null; then
        if ! sudo yum install -y $i; then
            echo "Failed to install $i package..."
            exit 1
        fi
    fi
done

# install pip dependencies
sudo pip3 install python-ipmi gitpython pygerrit2

# Required packages to redirect stdin with virt-customize
if ! sudo yum -y install libguestfs libguestfs-tools libguestfs-tools-c supermin supermin5 supermin-helper perl-Sys-Guestfs python-libguestfs libvirt-devel; then
    echo "Failed to install supermin/libguestfs packages..."
    exit 1
fi
