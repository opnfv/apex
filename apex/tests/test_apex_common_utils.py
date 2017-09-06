##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import ipaddress
import os

from apex.common import utils
from apex.settings.network_settings import NetworkSettings
from apex.tests.constants import (
    TEST_CONFIG_DIR,
    TEST_PLAYBOOK_DIR)

from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_not_is_instance)

NET_SETS = os.path.join(TEST_CONFIG_DIR, 'network', 'network_settings.yaml')


class TestCommonUtils:
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

    def test_str2bool(self):
        assert_equal(utils.str2bool(True), True)
        assert_equal(utils.str2bool(False), False)
        assert_equal(utils.str2bool("True"), True)
        assert_equal(utils.str2bool("YES"), True)

    def test_parse_yaml(self):
        assert_is_instance(utils.parse_yaml(NET_SETS), dict)

    def test_dict_to_string(self):
        net_settings = NetworkSettings(NET_SETS)
        output = utils.dict_objects_to_str(net_settings)
        assert_is_instance(output, dict)
        for k, v in output.items():
            assert_is_instance(k, str)
            assert_not_is_instance(v, ipaddress.IPv4Address)

    def test_run_ansible(self):
        playbook = 'apex/tests/playbooks/test_playbook.yaml'
        assert_equal(utils.run_ansible(None, os.path.join(playbook),
                                       dry_run=True), None)
