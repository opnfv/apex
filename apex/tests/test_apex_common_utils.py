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
import shutil
import urllib.error

from apex.common import exceptions
from apex.common import utils
from apex.settings.network_settings import NetworkSettings
from apex.tests.constants import (
    TEST_CONFIG_DIR,
    TEST_PLAYBOOK_DIR)

from mock import patch, mock_open
from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_not_is_instance,
    assert_raises)

NET_SETS = os.path.join(TEST_CONFIG_DIR, 'network', 'network_settings.yaml')
a_mock_open = mock_open(read_data=None)


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

    def test_failed_run_ansible(self):
        playbook = 'apex/tests/playbooks/test_failed_playbook.yaml'
        assert_raises(Exception, utils.run_ansible, None,
                      os.path.join(playbook), dry_run=True)

    def test_fetch_upstream_and_unpack(self):
        url = 'https://github.com/opnfv/apex/blob/master/'
        utils.fetch_upstream_and_unpack('/tmp/fetch_test',
                                        url, ['INFO'])
        assert os.path.isfile('/tmp/fetch_test/INFO')
        shutil.rmtree('/tmp/fetch_test')

    def test_fetch_upstream_previous_file(self):
        test_file = 'overcloud-full.tar.md5'
        url = 'https://images.rdoproject.org/master/delorean/' \
              'current-tripleo/stable/'
        os.makedirs('/tmp/fetch_test', exist_ok=True)
        open("/tmp/fetch_test/{}".format(test_file), 'w').close()
        utils.fetch_upstream_and_unpack('/tmp/fetch_test',
                                        url, [test_file])
        assert os.path.isfile("/tmp/fetch_test/{}".format(test_file))
        shutil.rmtree('/tmp/fetch_test')

    def test_fetch_upstream_invalid_url(self):
        url = 'http://notavalidsite.com/'
        assert_raises(urllib.error.URLError,
                      utils.fetch_upstream_and_unpack, '/tmp/fetch_test',
                      url, ['INFO'])
        shutil.rmtree('/tmp/fetch_test')

    def test_fetch_upstream_and_unpack_tarball(self):
        url = 'http://artifacts.opnfv.org/apex/tests/'
        utils.fetch_upstream_and_unpack('/tmp/fetch_test',
                                        url, ['dummy_test.tar'])
        assert os.path.isfile('/tmp/fetch_test/test.txt')
        shutil.rmtree('/tmp/fetch_test')

    def test_nofetch_upstream_and_unpack(self):
        test_file = 'overcloud-full.tar.md5'
        url = 'https://images.rdoproject.org/master/delorean/' \
              'current-tripleo/stable/'
        os.makedirs('/tmp/fetch_test', exist_ok=True)
        target = "/tmp/fetch_test/{}".format(test_file)
        open(target, 'w').close()
        target_mtime = os.path.getmtime(target)
        utils.fetch_upstream_and_unpack('/tmp/fetch_test',
                                        url, [test_file], fetch=False)
        post_target_mtime = os.path.getmtime(target)
        shutil.rmtree('/tmp/fetch_test')
        assert_equal(target_mtime, post_target_mtime)

    def test_nofetch_upstream_and_unpack_no_target(self):
        test_file = 'overcloud-full.tar.md5'
        url = 'https://images.rdoproject.org/master/delorean/' \
              'current-tripleo/stable/'
        utils.fetch_upstream_and_unpack('/tmp/fetch_test',
                                        url, [test_file])
        assert os.path.isfile("/tmp/fetch_test/{}".format(test_file))
        shutil.rmtree('/tmp/fetch_test')

    def test_open_webpage(self):
        output = utils.open_webpage('http://opnfv.org')
        assert output is not None

    def test_open_invalid_webpage(self):
        assert_raises(urllib.request.URLError, utils.open_webpage,
                      'http://inv4lIdweb-page.com')

    @patch('builtins.open', a_mock_open)
    @patch('yaml.safe_dump')
    @patch('yaml.safe_load')
    def test_edit_tht_env(self, mock_yaml_load, mock_yaml_dump):
        settings = {'SomeParameter': 'some_value'}
        mock_yaml_load.return_value = {
            'parameter_defaults': {'SomeParameter': 'dummy'}
        }
        utils.edit_tht_env('/dummy-environment.yaml', 'parameter_defaults',
                           settings)
        new_data = {'parameter_defaults': settings}
        mock_yaml_dump.assert_called_once_with(new_data, a_mock_open(),
                                               default_flow_style=False)
