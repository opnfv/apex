#!/usr/bin/env bash

cd /root/yardstick

python setup.py develop easy_install yardstick[plot] &> /root/install_yardstick-plot.log
