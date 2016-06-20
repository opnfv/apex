##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import sys

from test_apex_ip_utils import get_default_gateway_linux
from apex_python_utils import main
from apex_python_utils import get_parser
from apex_python_utils import parse_net_settings
from apex_python_utils import parse_deploy_settings
from apex_python_utils import find_ip
from apex_python_utils import build_nic_template

from nose.tools import assert_equal
from nose.tools import assert_raises


net_sets = '../config/network/network_settings.yaml'
net_env = '../build/network-environment.yaml'
deploy_sets = '../config/deploy/deploy_settings.yaml'
nic_template = '../build/nics-controller.yaml.jinja2'


class TestCommonUtils(object):
    @classmethod
    def setup_class(klass):
        """This method is run once for each class before any tests are run"""
        klass.parser = get_parser()
        klass.iface_name = get_default_gateway_linux()

    @classmethod
    def teardown_class(klass):
        """This method is run once for each class _after_ all tests are run"""

    def setUp(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_main(self):
        sys.argv = ['apex_python_utils', '-l', '/dev/null']
        assert_raises(SystemExit, main)
        sys.argv = ['apex_python_utils', '--debug', '-l', '/dev/null']
        assert_raises(SystemExit, main)
        sys.argv = ['apex_python_utils', '-l', '/dev/null',
                                         'parse-deploy-settings',
                                         '-f', deploy_sets]
        assert_equal(main(), None)

    def test_parse_net_settings(self):
        args = self.parser.parse_args(['parse-net-settings',
                                       '-s', net_sets,
                                       '-i', 'True',
                                       '-e', net_env])
        assert_equal(parse_net_settings(args), None)

    def test_parse_deploy_settings(self):
        args = self.parser.parse_args(['parse-deploy-settings',
                                       '-f', self.deploy_sets])
        assert_equal(parse_deploy_settings(args), None)

    def test_find_ip(self):
        args = self.parser.parse_args(['find-ip',
                                       '-i', self.iface_name])
        assert_equal(find_ip(args), None)

    def test_build_nic_template(self):
        args = self.parser.parse_args(['nic-template',
                                       '-t', nic_template,
                                       '-n', 'admin_network'])
        assert_equal(build_nic_template(args), None)
