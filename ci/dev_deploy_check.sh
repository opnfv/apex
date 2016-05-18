#!/bin/sh
##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

# Make sure deploy deps are installed
if ! rpm -q rdo-release > /dev/null; then
    if ! sudo yum install -y  https://www.rdoproject.org/repos/rdo-release.rpm; then
        echo "Failed to install RDO Release package..."
        exit 1
    fi
fi
for i in epel-release openvswitch openstack-tripleo libguestfs libguestfs-tools-c libvirt-python; do
    if ! rpm -q $i > /dev/null; then
        if ! sudo yum install -y $i; then
            echo "Failed to install $i package..."
            exit 1
        fi
fi
