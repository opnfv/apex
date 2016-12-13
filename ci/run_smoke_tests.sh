#!/usr/bin/env bash

source ../lib/utility-functions.sh

export ANSIBLE_HOST_KEY_CHECKING=False

./dev_dep_check.sh

yum install python-devel -y
yum install openssl-devel -y
easy_install pip
pip install ansible

echo 'See ~stack/smoke-tests.out on the undercloud for result log'
ansible-playbook -i "$(get_undercloud_ip)," ../tests/smoke_tests/smoke_tests.yml
