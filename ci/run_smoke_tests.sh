#!/usr/bin/env bash

source ../lib/utility-functions.sh

ansible-playbook -i "$(get_undercloud_ip)," ./smoke_tests/smoke_tests.yml
