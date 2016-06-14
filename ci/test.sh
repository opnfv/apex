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
if ! rpm -q python34-devel > /dev/null; then
    sudo yum install -y epel-release
    if ! sudo yum install -y python34-devel; then
        echo "Failed to install python34-devel package..."
        exit 1
    fi
fi

if ! rpm -q python34-nose > /dev/null; then
    if ! sudo yum install -y python34-nose; then
        echo "Failed to install python34-nose package..."
        exit 1
    fi
fi

# Make sure coverage is installed
if ! python3 -c "import coverage" &> /dev/null; then sudo easy_install-3.4 coverage; fi

pushd ../build/ > /dev/null
make python-tests
popd > /dev/null
pushd ../tests/ > /dev/null
percent=$(coverage3 report --include '*lib/python/*' -m | grep TOTAL | tr -s ' ' | awk '{ print $4 }' | cut -d % -f 1)
if [[ percent -lt 80 ]]; then
    echo "Python Coverage: $percent"
    echo "Does not meet 80% requirement"
    exit 1
fi
popd > /dev/null
