#!/usr/bin/env bash

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

  # get dependencies
  sudo yum install -y yum-utils
  yumdownloader dejavu-sans-mono-fonts libstatgrab \
  log4cplus rrdtool rrdtool-devel mcelog python34 python34-libs \
  libvirt-python python-six python-babel python-pbr python-futures
 
#  curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"

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
#  git clone $PUPPET_BAROMETER_REPO
  git clone ~/puppet-barometer
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
     /opt/log4cplus*.rpm /opt/mcelog*.rpm \
     /opt/python34*.rpm /opt/python34-libs*.rpm /opt/libvirt-python*.rpm \
     /opt/python-pbr*.rpm /opt/python-babel*.rpm \
     /opt/python-futures*.rpm /opt/python-six*.rpm' \
  -a $OVERCLOUD_IMAGE

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

