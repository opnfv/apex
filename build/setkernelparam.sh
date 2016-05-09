#!/bin/bash

##############################################################################
# Copyright (c) 2016 Red Hat Inc.
# Michael Chapman <michapma@redhat.com>
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

GRUBCONF='/boot/grub2/grub.conf'

if [ "$1" == "" ]; then
  echo "No kernel parameter name provided, not modifying grub.conf"
  exit 1
fi

if [ "$2" == "" ]; then
  echo "No kernel parameter value provided, not modifying grub.conf"
  exit 1
fi

echo "Setting $1=$2 in $GRUBCONF"
echo "GRUB_CMDLINE_LINUX=\"\$GRUB_CMDLINE_LINUX $1=$2\"" >> /etc/default/grub
grub2-mkconfig > $GRUBCONF
exit 0
