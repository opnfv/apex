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
source ./variables.sh

pushd images > /dev/null

cp -f overcloud-full.qcow2 overcloud-full-opendaylight_build.qcow2

###############################################
#####    Adding OpenDaylight to overcloud #####
###############################################

# tar up fdio networking-odl
rm -rf fds
git clone https://gerrit.opnfv.org/gerrit/fds
pushd fds > /dev/null
tar -czvf ../networking-odl.tar.gz networking-odl
popd > /dev/null

# Beryllium Repo
cat > /tmp/opendaylight.repo << EOF
[opendaylight-4-release]
name=CentOS CBS OpenDaylight Beryllium repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-4-release/\$basearch/os/
enabled=1
gpgcheck=0
EOF

# Boron Repo
cat > /tmp/opendaylight_boron.repo << EOF
[opendaylight-5-release]
name=CentOS CBS OpenDaylight Boron repository
baseurl=http://cbs.centos.org/repos/nfv7-opendaylight-5-testing/\$basearch/os/
enabled=1
gpgcheck=0
EOF

#BGPVPN Repo
cat > /tmp/bgpvpn.repo << EOF
[bgpvpn]
name=bgpvpn
baseurl=https://trunk.rdoproject.org/centos7-master/9d/63/9d6331a4542cdf376b4b82efd52fbcd78e8d3197_d85bd41c
enabled=1
gpgcheck=0
priority=1
EOF

# SDNVPN - Copy tunnel setup script
wget https://raw.githubusercontent.com/openstack/fuel-plugin-opendaylight/brahmaputra-sr2/deployment_scripts/puppet/modules/opendaylight/templates/setup_TEPs.py


# install ODL packages
# install Jolokia for ODL HA
# Patch in OPNFV custom puppet-tripleO
# install Honeycomb
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload networking-odl.tar.gz:/root/ \
    --upload /tmp/opendaylight_boron.repo:/etc/yum.repos.d/opendaylight.repo \
    --run-command "yum install --downloadonly --downloaddir=/root/boron/ opendaylight" \
    --upload /tmp/opendaylight.repo:/etc/yum.repos.d/opendaylight.repo \
    --install opendaylight,python-networking-odl \
    --upload /tmp/bgpvpn.repo:/etc/yum.repos.d/bgpvpn.repo \
    --install python-networking-bgpvpn \
    --run-command "wget https://github.com/rhuss/jolokia/releases/download/v1.3.3/jolokia-1.3.3-bin.tar.gz -O /tmp/jolokia-1.3.3-bin.tar.gz" \
    --run-command "tar -xvf /tmp/jolokia-1.3.3-bin.tar.gz -C /opt/opendaylight/system/org" \
    --install honeycomb \
    --upload ./setup_TEPs.py:/tmp \
    -a overcloud-full-opendaylight_build.qcow2

    # Move these two lines above the -a overcloud-full-opendaylight_build.qcow2 when the patch has been rebased
    #--upload ../opnfv-puppet-tripleo.patch:/tmp \
    #--run-command "cd /etc/puppet/modules/tripleo && patch -Np1 < /tmp/opnfv-puppet-tripleo.patch" \

## WORK AROUND
## when OpenDaylight lands in upstream RDO manager this can be removed

# upload the opendaylight puppet module
rm -rf puppet-opendaylight
git clone -b master https://github.com/dfarrell07/puppet-opendaylight
pushd puppet-opendaylight > /dev/null
git archive --format=tar.gz --prefix=opendaylight/ HEAD > ../puppet-opendaylight.tar.gz
popd > /dev/null
LIBGUESTFS_BACKEND=direct virt-customize --upload puppet-opendaylight.tar.gz:/etc/puppet/modules/ \
                                         --run-command "cd /etc/puppet/modules/ && tar xzf puppet-opendaylight.tar.gz" \
                                         -a overcloud-full-opendaylight_build.qcow2

mv overcloud-full-opendaylight_build.qcow2 overcloud-full-opendaylight.qcow2
popd > /dev/null
