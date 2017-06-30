#!/usr/bin/env bash

# Get and install packages needed for Barometer service.
# These are: collectd rpm's and dependencies, collectd-ceilometer-plugin, 
# puppet-barometer module.

# Versions of packages
COLLECTD_VER="5.7.1.342.g8eee594-6.el7.centos.x86_64.rpm"
INTEL_CMT_CAT_VER="0.1.5-1.el7.centos.x86_64.rpm"

# Locations of repos
ARTIFACTS_BAROM="artifacts.opnfv.org/barometer/rpms"
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
  # get dependencies
  yum install -y yum-utils
  yumdownloader dejavu-sans-mono-fonts libstatgrab \
  log4cplus rrdtool rrdtool-devel mcelog python34 python34-libs
  
  wget $ARTIFACTS_BAROM/libcollectdclient-$COLLECTD_VER
  wget $ARTIFACTS_BAROM/libcollectdclient-devel-$COLLECTD_VER 
  wget $ARTIFACTS_BAROM/collectd-$COLLECTD_VER
  wget $ARTIFACTS_BAROM/collectd-utils-$COLLECTD_VER 
  wget $ARTIFACTS_BAROM/collectd-ovs_events-$COLLECTD_VER
  wget $ARTIFACTS_BAROM/collectd-ovs_stats-$COLLECTD_VER 
  wget $ARTIFACTS_BAROM/intel-cmt-cat-$INTEL_CMT_CAT_VER 
  wget $ARTIFACTS_BAROM/intel-cmt-cat-debuginfo-$INTEL_CMT_CAT_VER 
  wget $ARTIFACTS_BAROM/collectd-rrdcached-$COLLECTD_VER
  wget $ARTIFACTS_BAROM/collectd-rrdtool-$COLLECTD_VER
  wget $ARTIFACTS_BAROM/collectd-python-$COLLECTD_VER
  tar cfz collectd.tar.gz *.rpm
  mv collectd.tar.gz ${BUILD_DIR}
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

  # install dependencies
  LIBGUESTFS_BACKEND=direct virt-customize \
     --run-command 'yum localinstall -y \
     /opt/dejavu-sans-mono-fonts*.noarch.rpm \
     /opt/rrdtool*.rpm /opt/rrdtool-devel*.rpm /opt/libstatgrab*.rpm \
     /opt/log4cplus*.rpm /opt/mcelog*.rpm /opt/python34*.rpm \
     /opt/python34-libs*.rpm' \
  -a $OVERCLOUD_IMAGE

  LIBGUESTFS_BACKEND=direct virt-customize \
     --run-command "rpm -iv \
     /opt/libcollectdclient-${COLLECTD_VER} \
     /opt/libcollectdclient-devel-${COLLECTD_VER} \
     /opt/collectd-${COLLECTD_VER} \
     /opt/collectd-utils-${COLLECTD_VER} \
     /opt/collectd-python-${COLLECTD_VER} \
     /opt/collectd-ovs_events-${COLLECTD_VER} \
     /opt/collectd-ovs_stats-${COLLECTD_VER} \
     /opt/intel-cmt-cat-${INTEL_CMT_CAT_VER} \
     /opt/intel-cmt-cat-debuginfo-${INTEL_CMT_CAT_VER} \
     /opt/collectd-rrdcached-${COLLECTD_VER} \
     /opt/collectd-rrdtool-${COLLECTD_VER}" \
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

