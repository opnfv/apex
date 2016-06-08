##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

from apex.network_settings import NetworkSettings

from nose.tools import assert_equal
from nose.tools import assert_is_instance


class TestNetworkSettings(object):
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

    def test_init(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)

    def test_dump_bash(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_equal(ns.dump_bash(), None)
        assert_equal(ns.dump_bash(path='/dev/null'), None)

    def test_get_network_settings(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_is_instance(ns.get_network_settings(), dict)

    def test_get_enabled_networks(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        assert_is_instance(ns.get_enabled_networks(), list)
