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

from apex.common import utils
from apex.settings.network_settings import NetworkSettings
from apex.tests.constants import (
    TEST_CONFIG_DIR,
    TEST_PLAYBOOK_DIR)

from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_not_is_instance,
    assert_raises)

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
        url = 'https://images.rdoproject.org/master/delorean/' \
              'current-tripleo/stable/'
        os.makedirs('/tmp/fetch_test', exist_ok=True)
        open('/tmp/fetch_test/delorean_hash.txt', 'w').close()
        utils.fetch_upstream_and_unpack('/tmp/fetch_test',
                                        url, ['delorean_hash.txt'])
        assert os.path.isfile('/tmp/fetch_test/delorean_hash.txt')
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
