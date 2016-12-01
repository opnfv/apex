#!/bin/bash
set -e
apex_home=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export CONFIG=$apex_home/build
export LIB=$apex_home/lib
export RESOURCES=$apex_home/build/images/
export PYTHONPATH=$PYTHONPATH:$apex_home/lib/python
$apex_home/ci/dev_dep_check.sh
pushd $apex_home/build
make clean
make undercloud
make overcloud-opendaylight
pushd $apex_home/ci
./clean.sh
./dev_dep_check.sh
out=/tmp/opnfv-deploy.out
echo "All further output will be piped to $out"
(nohup ./deploy.sh -v -n $apex_home/config/network/network_settings.yaml -d $apex_home/config/deploy/os-odl_l3-nofeature-noha.yaml &> $out &)
popd
