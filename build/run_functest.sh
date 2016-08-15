#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2016 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

redirect="/dev/null"
if ! which docker; then
  sudo yum install -y docker
fi

if ! which docker; then
  echo "Failed to install docker, exiting..."
  exit 1
fi

sudo systemctl start docker

. stackrc

docker pull opnfv/functest:master 2> ${redirect}

stackrc="-v /home/stack/stackrc:/home/opnfv/functest/conf/stackrc"
sshkey="-v /root/.ssh/id_rsa:/root/.ssh/id_rsa"

if sudo iptables -C FORWARD -o virbr0 -j REJECT --reject-with icmp-port-unreachable 2> ${redirect}; then
  sudo iptables -D FORWARD -o virbr0 -j REJECT --reject-with icmp-port-unreachable
fi
if sudo iptables -C FORWARD -i virbr0 -j REJECT --reject-with icmp-port-unreachable 2> ${redirect}; then
  sudo iptables -D FORWARD -i virbr0 -j REJECT --reject-with icmp-port-unreachable
fi

# something not right with this line...
#if ! sudo iptables -C FORWARD -j RETURN 2> ${redirect} || ! sudo iptables -L FORWARD | awk 'NR==3' | grep RETURN 2> ${redirect}; then
#    sudo iptables -I FORWARD -j RETURN
#fik

DEPLOY_SCENARIO=os-nosdn-nofeature-noha
INSTALLER_IP=$(facter ipaddress)
DEPLOY_TYPE="virt"

# placeholder - uses the git branch in CI
branch="current"
dir_result="${HOME}/opnfv/functest/results/${branch}"
mkdir -p ${dir_result}
sudo rm -rf ${dir_result}/*
res_volume="-v ${dir_result}:/home/opnfv/functest/results"

envs="-e INSTALLER_TYPE=apex -e INSTALLER_IP=${INSTALLER_IP} -e DEPLOY_SCENARIO=${DEPLOY_SCENARIO} -e DEPLOY_TYPE=${DEPLOY_TYPE}"

container_id=$(sudo docker run --privileged=true -id ${envs} ${stackrc} ${res_volume} ${sshkey} opnfv/functest:master /bin/bash)
docker exec ${container_id} /home/opnfv/repos/functest/ci/prepare_env.py start
