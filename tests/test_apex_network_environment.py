##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

from apex.network_settings import NetworkSettings
from apex.network_environment import NetworkEnvironment
from apex.network_environment import NetworkEnvException

from nose.tools import assert_equal
from nose.tools import assert_raises
from nose.tools import assert_is_instance


class TestNetworkEnvironment(object):
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
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        assert_raises(NetworkEnvException, NetworkEnvironment, None, '../build/network-environment.yaml')

    def test_get_netenv_settings(self):
        ns = NetworkSettings('../config/network/network_settings.yaml', True)
        ne = NetworkEnvironment(ns, '../build/network-environment.yaml')
        assert_is_instance(ne.get_netenv_settings(), dict)
