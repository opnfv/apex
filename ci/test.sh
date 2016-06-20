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
for pkg in epel-release python34-devel python34-nose python-pep8; do
  if ! rpm -q ${pkg} > /dev/null; then
    if ! sudo yum install -y ${pkg}; then
      echo "Failed to install ${pkg} package..."
      exit 1
    fi
  fi
done

# Make sure coverage is installed
if ! python3 -c "import coverage" &> /dev/null; then sudo easy_install-3.4 coverage; fi

pushd ../build/ > /dev/null
make python-tests
make python-pep8-check
popd > /dev/null
