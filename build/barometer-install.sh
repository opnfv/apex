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
source ./variables.sh

# Versions/branches
COLLECTD_OPENSTACK_PLUGINS_BRANCH="stable/pike"

ARCH="8.el7.centos.x86_64.rpm"

# don't fail because of missing certificate
GETFLAG="--no-check-certificate"

# Locations of repos
ARTIFACTS_BAROM="artifacts.opnfv.org/barometer"
COLLECTD_OPENSTACK_REPO="https://github.com/openstack/collectd-openstack-plugins"
PUPPET_BAROMETER_REPO="https://github.com/opnfv/barometer.git"

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

  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/libcollectdclient-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/libcollectdclient-devel-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-utils-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-python-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ovs_events-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ovs_stats-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/intel-cmt-cat-${RDT_SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/intel-cmt-cat-devel-${RDT_SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-intel_rdt-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-snmp-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-snmp_agent-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-virt-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-sensors-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ceph-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-curl_json-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-apache-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-write_http-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-mysql-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ping-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-smart-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-curl_xml-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-disk-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-rrdcached-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-iptables-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-curl-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-ipmi-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-netlink-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-rrdtool-${SUFFIX}
  wget $GETFLAG $ARTIFACTS_BAROM/$BAROMETER_VER/collectd-lvm-${SUFFIX}
  curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"

  tar cfz collectd.tar.gz *.rpm get-pip.py
  cp collectd.tar.gz ${BUILD_DIR}
  popd > /dev/null

  # get collectd-openstack-plugins and tar it
  rm -rf collectd-openstack-plugins
  git clone $COLLECTD_OPENSTACK_REPO collectd-openstack-plugins
  pushd collectd-openstack-plugins
  git checkout $COLLECTD_OPENSTACK_PLUGINS_BRANCH
  git archive --format=tar.gz HEAD > ${BUILD_DIR}/collectd-openstack-plugins.tar.gz
  popd > /dev/null

  # get the barometer puppet module and tar it
  rm -rf puppet-barometer
  git clone $PUPPET_BAROMETER_REPO puppet-barometer
  pushd puppet-barometer/puppet-barometer/ > /dev/null
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
  LIBGUESTFS_BACKEND=direct $VIRT_CUSTOMIZE \
    --upload ${BUILD_DIR}/collectd.tar.gz:/opt/ \
    --upload ${BUILD_DIR}/collectd-openstack-plugins.tar.gz:/opt/ \
    --upload ${BUILD_DIR}/puppet-barometer.tar.gz:/etc/puppet/modules/ \
    --run-command 'tar xfz /opt/collectd.tar.gz -C /opt' \
    --install libstatgrab,log4cplus,rrdtool,rrdtool-devel \
    --install mcelog,python34,python34-libs,python34-devel \
    --install libvirt,libvirt-devel,gcc \
    -a $OVERCLOUD_IMAGE

  LIBGUESTFS_BACKEND=direct $VIRT_CUSTOMIZE \
    --run-command 'python3.4 /opt/get-pip.py' \
    --run-command 'pip3 install requests libvirt-python pbr babel future six' \
    -a $OVERCLOUD_IMAGE

  LIBGUESTFS_BACKEND=direct $VIRT_CUSTOMIZE \
    --run-command 'yum remove -y collectd-write_sensu-5.8.0-2.el7.x86_64' \
    -a $OVERCLOUD_IMAGE

  LIBGUESTFS_BACKEND=direct $VIRT_CUSTOMIZE \
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
    /opt/collectd-virt-${SUFFIX} \
    /opt/collectd-sensors-${SUFFIX} \
    /opt/collectd-ceph-${SUFFIX} \
    /opt/collectd-curl_json-${SUFFIX} \
    /opt/collectd-apache-${SUFFIX} \
    /opt/collectd-write_http-${SUFFIX} \
    /opt/collectd-mysql-${SUFFIX} \
    /opt/collectd-ping-${SUFFIX} \
    /opt/collectd-smart-${SUFFIX} \
    /opt/collectd-curl_xml-${SUFFIX} \
    /opt/collectd-disk-${SUFFIX} \
    /opt/collectd-rrdcached-${SUFFIX} \
    /opt/collectd-iptables-${SUFFIX} \
    /opt/collectd-curl-${SUFFIX} \
    /opt/collectd-ipmi-${SUFFIX} \
    /opt/collectd-netlink-${SUFFIX} \
    /opt/collectd-rrdtool-${SUFFIX} \
    /opt/collectd-lvm-${SUFFIX}" \
    -a $OVERCLOUD_IMAGE

  # install collectd-openstack-plugins
  # install puppet-barometer module
  # make directories for config files and mibs
  LIBGUESTFS_BACKEND=direct $VIRT_CUSTOMIZE \
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
