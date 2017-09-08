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
from apex.common import parsers as apex_parsers
from apex.common.exceptions import ApexDeployException
from nose.tools import (
    assert_is_instance,
    assert_dict_equal,
    assert_raises
)


class TestCommonParsers:
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

    def test_parse_nova_output(self):
        output = apex_parsers.parse_nova_output(
            os.path.join(con.TEST_DUMMY_CONFIG, 'nova_output.json'))
        assert_is_instance(output, dict)
        nodes = {
            'overcloud-controller-0': '192.30.9.8',
            'overcloud-novacompute-0': '192.30.9.10',
            'overcloud-novacompute-1': '192.30.9.9'
        }
        assert_dict_equal(output, nodes)

    def test_negative_parse_nova_output(self):
        assert_raises(ApexDeployException, apex_parsers.parse_nova_output,
                      os.path.join(con.TEST_DUMMY_CONFIG,
                                   'bad_nova_output.json'))

    def test_parse_overcloudrc(self):
        output = apex_parsers.parse_overcloudrc(
            os.path.join(con.TEST_DUMMY_CONFIG, 'test_overcloudrc'))
        assert_is_instance(output, dict)
        assert 'OS_AUTH_TYPE' in output.keys()
        assert output['OS_AUTH_TYPE'] == 'password'
        assert 'OS_PASSWORD' in output.keys()
        assert output['OS_PASSWORD'] == 'Wd8ruyf6qG8cmcms6dq2HM93f'

    def test_parse_ifcfg(self):
        output = apex_parsers.parse_ifcfg_file(
            os.path.join(con.TEST_DUMMY_CONFIG, 'ifcfg-br-external'))
        assert_is_instance(output, dict)
