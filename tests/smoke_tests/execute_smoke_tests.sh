#!/usr/bin/env bash

python ~/snaps/snaps/unit_test_suite.py -e ~stack/overcloudrc -n external -k -l INFO &> ~stack/smoke-tests.out