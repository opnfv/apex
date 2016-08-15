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

DOCKER_TAG="${DOCKER_TAG:-master}"
docker pull opnfv/functest:$DOCKER_TAG 2> ${redirect}

STACKRC="-v /home/stack/stackrc:/home/opnfv/functest/conf/stackrc"
SSHKEY="-v /root/.ssh/id_rsa:/root/.ssh/id_rsa"

if sudo iptables -C FORWARD -o virbr0 -j REJECT --reject-with icmp-port-unreachable 2> ${redirect}; then
  sudo iptables -D FORWARD -o virbr0 -j REJECT --reject-with icmp-port-unreachable
fi
if sudo iptables -C FORWARD -i virbr0 -j REJECT --reject-with icmp-port-unreachable 2> ${redirect}; then
  sudo iptables -D FORWARD -i virbr0 -j REJECT --reject-with icmp-port-unreachable
fi

# something not right with this line...
#if ! sudo iptables -C FORWARD -j RETURN 2> ${redirect} || ! sudo iptables -L FORWARD | awk 'NR==3' | grep RETURN 2> ${redirect}; then
#    sudo iptables -I FORWARD -j RETURN
#fi

DEPLOY_SCENARIO=os-nosdn-nofeature-noha
INSTALLER_IP=$(facter ipaddress)
DEPLOY_TYPE="virt"

CONTAINER_NAME="functest-${DOCKER_TAG}"

# placeholder - uses the git branch in CI
BRANCH=${GIT_BRANCH##*/}
BRANCH=${BRANCH:-default}
DIR_RESULT="${HOME}/opnfv/functest/results/${BRANCH}"
mkdir -p ${DIR_RESULT}
sudo rm -rf ${DIR_RESULT}/*
RES_VOLUME="-v ${DIR_RESULT}:/home/opnfv/functest/results"

ENVS="-e INSTALLER_TYPE=apex -e INSTALLER_IP=${INSTALLER_IP} -e DEPLOY_SCENARIO=${DEPLOY_SCENARIO} -e DEPLOY_TYPE=${DEPLOY_TYPE}"

CONTAINER_NAME="functest-${DOCKER_TAG}-${BRANCH}"
CONTAINER_ID=$(docker ps -f name=${CONTAINER_NAME} -q)
if [ "$CONTAINER_ID" == "" ]; then
  CONTAINER_ID=$(sudo docker run --name ${CONTAINER_NAME} --privileged=true -id ${ENVS} ${STACKRC} ${RES_VOLUME} ${SSHKEY} opnfv/functest:${DOCKER_TAG} /bin/bash)
fi

if [ "$CONTAINER_ID" == "" ]; then
  echo "Failed to run functest container, exiting..."
  exit 1
fi

docker exec ${CONTAINER_ID} /home/opnfv/repos/functest/ci/prepare_env.py start
