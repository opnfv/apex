#!/usr/bin/env bash

# Copyright 2017 Intel Corporation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Get and install packages needed for Barometer service.
# These are: collectd rpm's and dependencies, collectd-openstack-plugins,
# puppet-barometer module.

# Versions/branches
COLLECTD_OPENSTACK_PLUGINS_BRANCH="stable/ocata"

ARCH="6.el7.centos.x86_64.rpm"
# don't fail because of missing certificate
GETFLAG="--no-check-certificate"

# Locations of repos
ARTIFACTS_BAROM="artifacts.opnfv.org/barometer"
COLLECTD_OPENSTACK_REPO="https://github.com/openstack/collectd-ceilometer-plugin"
PUPPET_BAROMETER_REPO="https://github.com/johnhinman/puppet-barometer"

# upload barometer packages tar, extract, and install

function barometer_pkgs {
  OVERCLOUD_IMAGE=$1

  # get collectd packages and upload to image
  echo "adding barometer to " $1
  rm -rf barometer
  mkdir barometer
  pushd barometer > /dev/null

  # get version of barometer packages to download
  wget $GETFLAG $ARTIFACTS_BAROM/latest.properties
  BAROMETER_VER=$(grep OPNFV_ARTIFACT_VERSION ./latest.properties | cut -d'=' -f2)
  echo "BAROMETER version = $BAROMETER_VER"

  # get collectd version from HTML
  wget $GETFLAG $ARTIFACTS_BAROM.html
  COLLECTD_VER=$(grep "$BAROMETER_VER/collectd-debuginfo" ./barometer.html \
    | cut -d'-' -f7)
  SUFFIX=$COLLECTD_VER-$ARCH

  # get intel_rdt version
  INTEL_RDT_VER=$(grep "$BAROMETER_VER/intel-cmt-cat-devel" ./barometer.html \
    | cut -d'-' -f9)
  RDT_SUFFIX=$INTEL_RDT_VER-1.el7.centos.x86_64.rpm

  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/libcollectdclient-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/libcollectdclient-devel-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-utils-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ovs_events-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ovs_stats-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-virt-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/intel-cmt-cat-$RDT_SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/intel-cmt-cat-devel-$RDT_SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-python-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-snmp-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-snmp_agent-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-intel_rdt-$SUFFIX
  curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"

  tar cfz collectd.tar.gz *.rpm get-pip.py
  cp collectd.tar.gz ${BUILD_DIR}
  popd > /dev/null

  # get collectd-openstack-plugins and tar it
  rm -rf collectd-openstack-plugins
  git clone $COLLECTD_OPENSTACK_REPO collectd-openstack-plugins
  pushd collectd-openstack-plugins
  git checkout -b $COLLECTD_OPENSTACK_PLUGINS_BRANCH
  git archive --format=tar.gz HEAD > ${BUILD_DIR}/collectd-openstack-plugins.tar.gz
  popd > /dev/null

  # get the barometer puppet module and tar it
  rm -rf puppet-barometer
  git clone $PUPPET_BAROMETER_REPO
  pushd puppet-barometer/ > /dev/null
  git archive --format=tar.gz HEAD > ${BUILD_DIR}/puppet-barometer.tar.gz
  popd > /dev/null

  # get mibs for the snmp plugin
  rm -rf barometer
  git clone https://gerrit.opnfv.org/gerrit/barometer
  pushd barometer/mibs > /dev/null
  git archive --format=tar.gz HEAD > ${BUILD_DIR}/mibs.tar.gz
  popd > /dev/null

  # Upload tar files to image
  # untar collectd packages
  # install dependencies
  LIBGUESTFS_BACKEND=direct virt-customize \
    --upload ${BUILD_DIR}/collectd.tar.gz:/opt/ \
    --upload ${BUILD_DIR}/collectd-openstack-plugins.tar.gz:/opt/ \
    --upload ${BUILD_DIR}/puppet-barometer.tar.gz:/etc/puppet/modules/ \
    --run-command 'tar xfz /opt/collectd.tar.gz -C /opt' \
    --install libstatgrab,log4cplus,rrdtool,rrdtool-devel \
    --install mcelog,python34,python34-libs,python34-devel \
    --install libvirt,libvirt-devel,gcc \
    -a $OVERCLOUD_IMAGE

  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command 'python3.4 /opt/get-pip.py' \
    --run-command 'pip3 install requests libvirt-python pbr babel future six' \
    -a $OVERCLOUD_IMAGE

  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "yum install -y \
    /opt/libcollectdclient-${SUFFIX} \
    /opt/libcollectdclient-devel-${SUFFIX} \
    /opt/collectd-${SUFFIX} \
    /opt/collectd-utils-${SUFFIX} \
    /opt/collectd-python-${SUFFIX} \
    /opt/collectd-ovs_events-${SUFFIX} \
    /opt/collectd-ovs_stats-${SUFFIX} \
    /opt/intel-cmt-cat-${RDT_SUFFIX} \
    /opt/intel-cmt-cat-devel-${RDT_SUFFIX} \
    /opt/collectd-intel_rdt-${SUFFIX} \
    /opt/collectd-snmp-${SUFFIX} \
    /opt/collectd-snmp_agent-${SUFFIX} \
    /opt/collectd-virt-${SUFFIX}" \
    -a $OVERCLOUD_IMAGE

  # install collectd-openstack-plugins
  # install puppet-barometer module
  # make directories for config files and mibs
  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command 'mkdir /opt/stack/collectd-openstack' \
    --run-command "tar xfz /opt/collectd-openstack-plugins.tar.gz -C /opt/stack/collectd-openstack" \
    --run-command "cd /etc/puppet/modules/ && mkdir barometer && \
      tar xzf puppet-barometer.tar.gz -C barometer" \
    --run-command 'mkdir /usr/share/mibs/' \
    --upload ${BUILD_DIR}/mibs.tar.gz:/usr/share/snmp/mibs/ \
    --run-command 'tar xfz /usr/share/snmp/mibs/mibs.tar.gz -C /usr/share/snmp/mibs/' \
    --run-command 'ln -s /usr/share/snmp/mibs/ /usr/share/mibs/ietf' \
    --run-command 'mkdir -p /etc/collectd/collectd.conf.d' \
    -a $OVERCLOUD_IMAGE
}

