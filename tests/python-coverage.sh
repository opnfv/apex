#!/bin/bash
set -x
all_networks="admin_network private_network storage_network external_network"

# exercise help
coverage-3.4 run ../lib/python/apex-python-utils.py -l /dev/null > /dev/null

# exercise parse-net-settings
# throw debug on the first to exercise it
coverage-3.4 run -a ../lib/python/apex-python-utils.py --debug parse-net-settings -f ../config/network/network_settings.yaml -i True -s ../build/network-environment.yaml> /dev/null

# exercise proper nic-template runs
coverage-3.4 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e interface -af 4 > /dev/null
coverage-3.4 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e interface -af 6 > /dev/null
coverage-3.4 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e br-ex -af 4 > /dev/null
coverage-3.4 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e br-ex -af 6 > /dev/null

# exercise find-ip
coverage-3.4 run -a ../lib/python/apex-python-utils.py -l /dev/null find-ip -i $(ip a | grep 2: | cut -d \  -f 2 | head -n 1 | cut -d : -f 1) > /dev/null

# generate reports
coverage-3.4 report --include '*lib/python/*' -m
coverage-3.4 html --include '*lib/python/*'
