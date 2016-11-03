#!/usr/bin/env bash

source ../lib/utility-functions.sh

export ANSIBLE_HOST_KEY_CHECKING=False

echo 'See ~stack/smoke-tests.out on the undercloud for result log'
ansible-playbook -i "$(get_undercloud_ip)," ../tests/smoke_tests/smoke_tests.yml
