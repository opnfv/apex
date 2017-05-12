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
export PYTHONPATH=$PYTHONPATH:$DIR/../lib/python
export APEX_PYTHON_UTILS=$DIR/../lib/python/apex_python_utils.py
rpm -q ansible || sudo yum -y install ansible
ansible-playbook --become -i "localhost," -c local $DIR/../lib/ansible/playbooks/build_dependencies.yml -vvv
make -C $DIR/../build clean
python3 $DIR/build.py $@
