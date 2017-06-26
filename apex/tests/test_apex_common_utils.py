##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import nose.tools

from apex import utils


class TestCommonUtils(object):
    @classmethod
    def setup_class(klass):
        """This method is run once for each class before any tests are run"""

    @classmethod
    def teardown_class(klass):
        """This method is run once for each class _after_ all tests are run"""

    def setUp(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_str2bool(self):
        nose.tools.assert_equal(utils.str2bool(True), True)
        nose.tools.assert_equal(utils.str2bool(False), False)
        nose.tools.assert_equal(utils.str2bool("True"), True)
        nose.tools.assert_equal(utils.str2bool("YES"), True)

    def test_parse_yaml(self):
        nose.tools.assert_is_instance(
            utils.parse_yaml('../config/network/network_settings.yaml'),
            dict)
