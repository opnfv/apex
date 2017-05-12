#!/bin/sh
##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

# Make sure python dependencies are installed
for pkg in yamllint iproute epel-release python34-devel python34-nose python34-PyYAML python-pep8 python34-mock python34-pip; do
  if ! rpm -q ${pkg} > /dev/null; then
    if ! sudo yum install -y ${pkg}; then
      echo "Failed to install ${pkg} package..."
      exit 1
    fi
  fi
done

for pip_pkg in coverage gitpython pygerrit2; do
  if ! python3 -c "import ${pip_pkg}" &> /dev/null; then
    sudo pip3 install ${pip_pkg}
  fi
done


pushd ../build/ > /dev/null
make python-pep8-check
make yamllint
make python-tests
popd > /dev/null
