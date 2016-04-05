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

populate_cache "$rdo_images_uri/undercloud.qcow2"
if [ ! -d images ]; then mkdir images/; fi
cp -f cache/undercloud.qcow2 images/

#Adding OpenStack packages to undercloud
pushd images > /dev/null

# install the packages above and enabling ceph to live on the controller
# OpenWSMan package update supports the AMT Ironic driver for the TealBox
LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "sed -i '/ControllerEnableCephStorage/c\\  ControllerEnableCephStorage: true' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller_pacemaker.pp" \
    --run-command "sed -i '/  \$enable_ceph = /c\\  \$enable_ceph = true' /usr/share/openstack-tripleo-heat-templates/puppet/manifests/overcloud_controller.pp" \
    --run-command "curl http://download.opensuse.org/repositories/Openwsman/CentOS_CentOS-7/Openwsman.repo > /etc/yum.repos.d/wsman.repo" \
    --run-command "yum update -y openwsman*" \
    --run-command "cp /usr/share/instack-undercloud/undercloud.conf.sample /home/stack/undercloud.conf && chown stack:stack /home/stack/undercloud.conf" \
    --upload ../opnfv-environment.yaml:/home/stack/ \
    -a undercloud.qcow2

# Patch in OpenDaylight installation and configuration
#LIBGUESTFS_BACKEND=direct virt-customize --upload ../opnfv-tripleo-heat-templates.patch:/tmp \
#                                         --run-command "cd /usr/share/openstack-tripleo-heat-templates/ && patch -Np1 < /tmp/opnfv-tripleo-heat-templates.patch" \
#                                         -a undercloud.qcow2

# Use apex tripleo-heat-templates fork
PR_NUMBER=$(git log -1 | grep 'opnfv-tht-pr:' | grep -o '[0-9]*')
REF="stable/colorado"
REPO="https://github.com/trozet/opnfv-tht"

if [ "$PR_NUMBER" != "" ]; then
  # Source credentials since we are rate limited to 60/day
  GHCREDS=""
  if [ -f ~/.githubcreds ]; then
    source ~/.githubcreds
    GHCREDS=" -u $GHUSERNAME:$GHACCESSTOKEN"
  fi

  PR=$(curl $GHCREDS https://api.github.com/repos/trozet/opnfv-tht/pulls/$PR_NUMBER)

  # Do not pull from merged branches
  MERGED=$(echo $PR | python -c "import sys,json; print json.load(sys.stdin)['head']['merged']")
  if [ "$MERGED" == false ]; then
    REF=$(echo $PR | python -c "import sys,json; print json.load(sys.stdin)['head']['ref']")
    REPO=$(echo $PR | python -c "import sys,json; print json.load(sys.stdin)['head']['repo']['git_url']")
  fi
fi

rm -rf opnfv-tht
git clone $REPO -b $REF opnfv-tht

pushd opnfv-tht > /dev/null
git archive --format=tar.gz --prefix=openstack-tripleo-heat-templates/ HEAD > ../opnfv-tht.tar.gz
popd > /dev/null
LIBGUESTFS_BACKEND=direct virt-customize --upload opnfv-tht.tar.gz:/usr/share \
                                         --run-command "cd /usr/share && rm -rf openstack-tripleo-heat-templates && tar xzf opnfv-tht.tar.gz" \
                                         -a undercloud.qcow2

popd > /dev/null

