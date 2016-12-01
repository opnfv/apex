#!/bin/bash
set -e
cd "$( dirname "${BASH_SOURCE[0]}" )"
export CONFIG=$(pwd)/build
export LIB=$(pwd)/lib
export RESOURCES=$(pwd)/build/images/
export PYTHONPATH=$PYTHONPATH:$(pwd)/lib/python
ci/dev_dep_check.sh
pushd build
make images-clean
make undercloud
make overcloud-opendaylight
pushd ../ci
./clean.sh
./dev_deploy_check.sh
./deploy.sh -v -n ~/apex/config/network/network_settings.yaml -d ~/apex/config/deploy/os-odl_l3-nofeature-noha.yaml
popd
