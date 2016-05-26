#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -e
source ./cache.sh
source ./variables.sh

populate_cache "$rdo_images_uri/overcloud-full.tar"
populate_cache "$openstack_congress"
populate_cache "$python_congressclient"

if [ ! -d images/ ]; then mkdir images; fi
tar -xf cache/overcloud-full.tar -C images/
mv -f images/overcloud-full.qcow2 images/overcloud-full_build.qcow2

##########################################################
#####  Prep initial overcloud image with common deps #####
##########################################################

pushd images > /dev/null

# tar up the congress puppet module
rm -rf puppet-congress
git clone https://github.com/opnfv/puppet-congress
pushd puppet-congress > /dev/null
git archive --format=tar.gz --prefix=congress/ HEAD > ../puppet-congress.tar.gz
popd > /dev/null

# enable connection tracking for protocal sctp
# add CPU pinning script
# install the congress rpms
# upload and explode the congress puppet module
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "echo 'nf_conntrack_proto_sctp' > /etc/modules-load.d/nf_conntrack_proto_sctp.conf" \
    --upload ../setkernelparam.sh:/root \
    --install "$openstack_congress" \
    --install "$python_congressclient" \
    --upload puppet-congress.tar.gz:/etc/puppet/modules/ \
    --run-command "cd /etc/puppet/modules/ && tar xzf puppet-congress.tar.gz" \
    -a overcloud-full_build.qcow2

mv -f overcloud-full_build.qcow2 overcloud-full.qcow2
popd > /dev/null
