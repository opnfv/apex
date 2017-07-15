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
# These are: collectd rpm's and dependencies, collectd-ceilometer-plugin, 
# puppet-barometer module.

# Versions of packages
COLLECTD_VER="5.7.1.342.g8eee594-6.el7.centos.x86_64.rpm"
INTEL_CMT_CAT_VER="1.0.1-1.el7.centos.x86_64.rpm"

ARCH="6.el7.centos.x86_64.rpm"
# don't fail because of missing certificate
GETFLAG="--no-check-certificate"

# Locations of repos
ARTIFACTS_BAROM="artifacts.opnfv.org/barometer"
COLLECTD_CEILOMETER_REPO="https://github.com/openstack/collectd-ceilometer-plugin"
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
  COLLECTD_VER=$(grep "$BAROMETER_VER/collectd-debuginfo" ./barometer.html | cut -d'-' -f7)
  SUFFIX=$COLLECTD_VER-$ARCH

  # download dependencies for local install. 
  # Could yum install directly from image with virt-customize,
  # but there seem to be connection errors. Time-out issues?
  sudo yum install -y yum-utils
  yumdownloader dejavu-sans-mono-fonts libstatgrab \
  log4cplus rrdtool rrdtool-devel mcelog \
  python34 python34-libs python34-devel \
  python-rpm-macros python-srpm-macros python3-rpm-macros \
  libvirt libvirt-devel gcc
 
  curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"

  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/libcollectdclient-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/libcollectdclient-devel-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-utils-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ovs_events-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ovs_stats-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/intel-cmt-cat-$INTEL_CMT_CAT_VER
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/intel-cmt-cat-devel-$INTEL_CMT_CAT_VER
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-rrdcached-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-rrdtool-$SUFFIX
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-python-$SUFFIX

  tar cfz collectd.tar.gz *.rpm get-pip.py
  cp collectd.tar.gz ${BUILD_DIR}
  popd > /dev/null

  # get collectd-ceilometer-plugin and tar it
  rm -rf collectd-ceilometer-plugin
  git clone https://github.com/openstack/collectd-ceilometer-plugin
  pushd collectd-ceilometer-plugin
  git archive --format=tar.gz HEAD > ${BUILD_DIR}/collectd-ceilometer-plugin.tar.gz
  popd > /dev/null

  # get the barometer puppet module and tar it
  rm -rf puppet-barometer
  git clone $PUPPET_BAROMETER_REPO
  pushd puppet-barometer/ > /dev/null
  git archive --format=tar.gz HEAD > ${BUILD_DIR}/puppet-barometer.tar.gz
  popd > /dev/null

  # Upload tar files to image
  LIBGUESTFS_BACKEND=direct virt-customize \
     --upload ${BUILD_DIR}/collectd.tar.gz:/opt/ \
     --upload ${BUILD_DIR}/collectd-ceilometer-plugin.tar.gz:/opt/ \
     --upload ${BUILD_DIR}/puppet-barometer.tar.gz:/etc/puppet/modules/ \
  -a $OVERCLOUD_IMAGE

  # untar collectd packages
  LIBGUESTFS_BACKEND=direct virt-customize \
     --run-command 'tar xfz /opt/collectd.tar.gz -C /opt' \
  -a $OVERCLOUD_IMAGE

#  LIBGUESTFS_BACKEND=direct virt-customize \
#     --run-command 'sudo yum install -y gcc python34 python34-libs python34-devel' \
#  -a $OVERCLOUD_IMAGE

  # install dependencies
  LIBGUESTFS_BACKEND=direct virt-customize \
     --run-command 'yum localinstall -y \
     /opt/dejavu-sans-mono-fonts*.noarch.rpm \
     /opt/rrdtool*.rpm /opt/rrdtool-devel*.rpm /opt/mcelog*.rpm \
     /opt/python34*.rpm /opt/python34-libs*.rpm /opt/python34-devel*.rpm \
     /opt/python-rpm-macros*.rpm /opt/python-srpm-macros*.rpm \
     /opt/python3-rpm-macros*.rpm \
     /opt/log4cplus*.rpm /opt/libstatgrab*.rpm /opt/gcc*.rpm \
     /opt/libvirt*.rpm /opt/libvirt-devel*.rpm' \
  -a $OVERCLOUD_IMAGE

  LIBGUESTFS_BACKEND=direct virt-customize \
     --run-command 'python3 /opt/get-pip.py' \
     --run-command 'pip3 install requests libvirt-python pbr babel future six' \
  -a $OVERCLOUD_IMAGE

#     /opt/libvirt*.rpm /opt/libvirt-devel*.rpm' \

  LIBGUESTFS_BACKEND=direct virt-customize \
     --run-command "rpm -iv \
     /opt/libcollectdclient-${SUFFIX} \
     /opt/libcollectdclient-devel-${SUFFIX} \
     /opt/collectd-${SUFFIX} \
     /opt/collectd-utils-${SUFFIX} \
     /opt/collectd-python-${SUFFIX} \
     /opt/collectd-ovs_events-${SUFFIX} \
     /opt/collectd-ovs_stats-${SUFFIX} \
     /opt/intel-cmt-cat-${INTEL_CMT_CAT_VER} \
     /opt/intel-cmt-cat-devel-${INTEL_CMT_CAT_VER} \
     /opt/collectd-rrdcached-${SUFFIX} \
     /opt/collectd-rrdtool-${SUFFIX}" \
     -a $OVERCLOUD_IMAGE

  # install collectd-ceilometer plugin
  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command 'mkdir /opt/collectd-ceilometer' \
    --run-command "tar xfz /opt/collectd-ceilometer-plugin.tar.gz -C /opt/collectd-ceilometer" \
    -a $OVERCLOUD_IMAGE

  # install puppet-barometer module
  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command "cd /etc/puppet/modules/ && mkdir barometer && \
      tar xzf puppet-barometer.tar.gz -C barometer" \
    -a $OVERCLOUD_IMAGE

  # make directory for config files
  LIBGUESTFS_BACKEND=direct virt-customize \
    --run-command 'mkdir /etc/collectd' \
    --run-command 'mkdir /etc/collectd/collectd.conf.d' \
    -a $OVERCLOUD_IMAGE
}

