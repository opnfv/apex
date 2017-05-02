#!/bin/bash
set -e
apex_home=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../
scenario=$1
if [[ ${scenario}x == x ]] || [ ! -e $apex_home/config/deploy/$scenario ];then
  echo "Please give scenario as 1 argument. Unknown scenario: $scenario"
  echo "Known: $(ls $apex_home/config/deploy/)"
  exit 1
fi

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
screen -S deploy_apex bash -c "./deploy.sh -v -n $apex_home/config/network/network_settings.yaml -d $apex_home/config/deploy/$scenario --virtual-computes 3 2>&1 | tee $out_file; echo "Installation end! ctrl-c to lock out" >> $out_file"
tail -f $out_file
popd
