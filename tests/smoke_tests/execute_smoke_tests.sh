#!/usr/bin/env bash

cd ~/provisioning/python
export PYTHONPATH=$PYTHONPATH:$(pwd)

python unit_test_suite.py ~stack/overcloudrc