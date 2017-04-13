#!/bin/bash
set -e
apex_home=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../
export BASE=$apex_home/build
export LIB=$apex_home/lib
export IMAGES=$apex_home/.build/
export PYTHONPATH=$PYTHONPATH:$apex_home/lib/python
$apex_home/ci/dev_dep_check.sh || true
$apex_home/ci/clean.sh
pushd $apex_home/build
make clean
make undercloud
make overcloud-opendaylight
popd
pushd $apex_home/ci
out_file=/tmp/apex-simple-deploy.log
echo "All further output will be piped to $out_file"
rm -f $out_file
function _deploy(){
  nohup ./deploy.sh -v -n $apex_home/config/network/network_settings.yaml -d $apex_home/config/deploy/os-odl-nofeature-noha.yaml > $out_file
  echo "Installation end! ctrl-c to lock out" >> $out_file
}
(_deploy &)
tail -f $out_file
popd
