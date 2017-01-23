#!/bin/bash

VIRTHOST=$1

if  [ ! -d "tripleo-quickstart" ]; then
  git clone https://github.com/openstack/tripleo-quickstart
fi

cd tripleo-quickstart
git fetch origin
git reset --hard origin/master

# external net bridges
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/21/406421/8 && git cherry-pick FETCH_HEAD
# ssh_user
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/03/422103/1 && git cherry-pick FETCH_HEAD
# virtualport types
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/47/407347/5 && git cherry-pick FETCH_HEAD
# run privileges
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/98/418198/7 && git cherry-pick FETCH_HEAD
# opnfv config
git fetch git://git.openstack.org/openstack/tripleo-quickstart refs/changes/93/422593/2 && git cherry-pick FETCH_HEAD

bash quickstart.sh -p quickstart-extras.yml -r requirements.txt -r quickstart-extras-requirements.txt -c config/general_config/opnfv.yml --tags all --teardown all -n -X $VIRTHOST

