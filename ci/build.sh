#!/bin/sh
##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
set -e
rpm -q ansible || sudo yum -y install ansible
ansible-playbook --become -i "localhost," -c local $LIB/ansible/playbooks/build_dependencies.yaml -vvv
make -C $DIR/../build clean
python3 $DIR/build.py $@
