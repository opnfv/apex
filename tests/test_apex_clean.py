##############################################################################
# Copyright (c) 2016 Tim Rozet (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import mock
import pyipmi
import pyipmi.chassis

from apex import clean_nodes
from mock import patch
from nose import tools


class TestClean(object):
    @classmethod
    def setup_class(klass):
        """This method is run once for each class before any tests are run"""

    @classmethod
    def teardown_class(klass_df):
        """This method is run once for each class _after_ all tests are run"""

    def setUp(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_clean(self):
        with mock.patch.object(pyipmi.Session, 'establish') as mock_method:
            with patch.object(pyipmi.chassis.Chassis,
                              'chassis_control_power_down') as mock_method2:
                clean_nodes('config/inventory.yaml')

        tools.assert_equal(mock_method.call_count, 5)
        tools.assert_equal(mock_method2.call_count, 5)
