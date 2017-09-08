#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

#Clean script to uninstall provisioning server for Apex
#author: Dan Radez (dradez@redhat.com)
#author: Tim Rozet (trozet@redhat.com)
set -e
yum -y install python34 python34-devel libvirt-devel python34-pip python-tox ansible
mkdir -p ~/tmp
mv -f .build ~/tmp/
sudo pip3 install --upgrade --force-reinstall .
mv -f ~/tmp/.build .
opnfv-clean $@
