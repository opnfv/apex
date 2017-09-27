#!/bin/bash
set -e
apex_home=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../
export PYTHONPATH=$apex_home/apex:$PYTHONPATH
$apex_home/contrib/dev_dep_check.sh || true
pip3 install -r $apex_home/requirements.txt
pushd $apex_home/apex
python3 clean.py
echo "All further output will be piped to $PWD/nohup.out"
(nohup python3 deploy.py -v -n ../config/network/network_settings.yaml -d ../config/deploy/os-nosdn-nofeature-noha.yaml --deploy-dir ../build --lib-dir ../lib --image-dir ../.build &)
[ -f nohup.out ] || sleep 3
tail -f nohup.out
popd
