#!/bin/bash
set -x
all_networks="admin_network private_network storage_network external_network"

# exercise help
coverage3 run ../lib/python/apex-python-utils.py -l /dev/null > /dev/null

# exercise parse-net-settings
# throw debug on the first to exercise it
coverage3 run -a ../lib/python/apex-python-utils.py --debug parse-net-settings -f ../config/network/network_settings.yaml -i True > /dev/null

# exercise proper nic-template runs
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e interface -af 4 > /dev/null
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e interface -af 6 > /dev/null
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e br-ex -af 4 > /dev/null
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null nic-template -t ../config/network/network_settings.yaml -n "$all_networks" -e br-ex -af 6 > /dev/null

# exercise find-ip
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null find-ip -i $(ip a | grep 2: | cut -d \  -f 2 | head -n 1 | cut -d : -f 1) > /dev/null

# exercise parse-deploy-settings
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f ../config/deploy/os-nosdn-nofeature-noha.yaml > /dev/null
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f ../config/deploy/os-nosdn-performance-ha.yaml > /dev/null

# excercise netenv-template
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null netenv-template -t ../build/network-environment.yaml --network-settings ../config/network/network_settings.yaml -n "$all_networks" > /dev/null

# generate reports
coverage3 report --include '*lib/python/*' -m
coverage3 html --include '*lib/python/*'
