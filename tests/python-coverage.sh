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

# exercise parse-deploy-settings errors
echo "global_params:" > /tmp/python-coverage.test
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f /tmp/python-coverage.test &> /dev/null
echo "deploy_options: string" > /tmp/python-coverage.test
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f /tmp/python-coverage.test &> /dev/null
echo "global_params:" >> /tmp/python-coverage.test
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f /tmp/python-coverage.test &> /dev/null
cat > /tmp/python-coverage.test << EOF
global_params:
deploy_options:
  error: error
EOF
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f /tmp/python-coverage.test &> /dev/null
cat > /tmp/python-coverage.test << EOF
global_params:
deploy_options:
  performance: string
EOF
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f /tmp/python-coverage.test &> /dev/null
cat > /tmp/python-coverage.test << EOF
global_params:
deploy_options:
  performance:
    error: error
EOF
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f /tmp/python-coverage.test &> /dev/null
cat > /tmp/python-coverage.test << EOF
global_params:
deploy_options:
  performance:
    Controller:
      error: error
EOF
coverage3 run -a ../lib/python/apex-python-utils.py -l /dev/null parse-deploy-settings -f /tmp/python-coverage.test &> /dev/null

# coverage for ip_utils
PYTHONPATH=../lib/python/ coverage3 run -a python_coverage_ip_utils.py $(ip r | grep default | awk '{ print $5 }')

# generate reports
coverage3 html --include '*lib/python/*'
coverage3 report --include '*lib/python/*' -m
