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
sudo python2 $DIR/check_dependencies.py -d build
python3 $DIR/build.py $@
