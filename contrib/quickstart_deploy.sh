#!/bin/bash
#
# Usage: ./quickstart-deploy.sh [name_of_machine_to_host_VMs]
#
# Will fail if run as root, and must have passwordless SSH from
# the current user to the root user of the target machine.
#
VIRTHOST=$1

current_dir=$(pwd)

BASE=${BASE:-"$HOME/apex"}

if  [ ! -d "tripleo-quickstart" ]; then
  git clone https://github.com/openstack/tripleo-quickstart
fi

INVENTORY=" -e apex_inventory_settings_file=$BASE/config/inventory/pod_example_settings.yaml "
DEPLOY=" -e apex_deploy_settings_file=$BASE/config/deploy/os-nosdn-nofeature-noha.yaml "
NETWORK=" -e apex_network_settings_file=$BASE/config/network/network_settings.yaml "
PLAYBOOK=" -p apex-noop.yml "
VIRTUAL=" -e apex_virtual=True "
CONFIG=" -c  $BASE/contrib/quickstart_defaults.yaml "
REQUIREMENTS=" -r $BASE/contrib/apex-requirements.txt -r requirements.txt "


cd tripleo-quickstart
git fetch origin
git reset --hard origin/master

# external net bridges
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/21/406421/8 && git cherry-pick FETCH_HEAD &&
# ssh_user
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/03/422103/1 && git cherry-pick FETCH_HEAD &&
# virtualport types
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/47/407347/7 && git cherry-pick FETCH_HEAD &&
# run privileges
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/98/418198/12 && git cherry-pick FETCH_HEAD &&
# opnfv config
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/93/422593/2 && git cherry-pick FETCH_HEAD

bash quickstart.sh -v $PLAYBOOK $REQUIREMENTS $NETWORK $DEPLOY $INVENTORY $VIRTUAL $CONFIG --tags all --teardown all -n -X $VIRTHOST

