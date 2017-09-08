##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os

from apex.tests import constants as con
from apex.network import jumphost
from apex.common.exceptions import ApexDeployException
from mock import patch
from nose.tools import (
    assert_is_instance,
    assert_dict_equal,
    assert_raises,
    assert_true,
    assert_false
)


def bridge_show_output(*args, **kwargs):
    return b"""
    b6f1b54a-b8ba-4e86-9c5b-733ab71b5712
    Bridge br-admin
        Port br-admin
            Interface br-admin
                type: internal
    ovs_version: "2.5.0"
"""


def bridge_port_list(*args, **kwargs):
    return b"""
enp6s0
vnet1
"""


class TestNetworkJumpHost:
    @classmethod
    def setup_class(cls):
        """This method is run once for each class before any tests are run"""

    @classmethod
    def teardown_class(cls):
        """This method is run once for each class _after_ all tests are run"""

    def setup(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    @patch('subprocess.check_output', side_effect=bridge_show_output)
    def test_is_ovs_bridge(self, bridge_output_function):
        assert_true(jumphost.is_ovs_bridge('br-admin'))
        assert_false(jumphost.is_ovs_bridge('br-blah'))

    @patch('subprocess.check_output', side_effect=bridge_port_list)
    def test_dump_ovs_ports(self, bridge_function):
        output = jumphost.dump_ovs_ports('br-admin')
        assert_is_instance(output, list)
        assert 'enp6s0' in output
