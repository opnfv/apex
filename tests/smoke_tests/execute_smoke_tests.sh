#!/usr/bin/env bash

cd ~/provisioning/python
export PYTHONPATH=$PYTHONPATH:$(pwd)

python unit_test_suite.py -e ~stack/overcloudrc -n external -l INFO