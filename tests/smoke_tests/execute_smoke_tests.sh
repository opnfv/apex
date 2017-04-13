#!/usr/bin/env bash

python ~/snaps/snaps/test_runner.py -e ~stack/overcloudrc -n external -c -a -i -f -k -l INFO &> ~stack/smoke-tests.out