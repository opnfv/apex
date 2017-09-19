##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import subprocess
import unittest

from mock import patch

from apex.virtual.utils import generate_inventory
from apex.virtual.utils import host_setup
from apex.virtual.utils import virt_customize

from nose.tools import (
    assert_regexp_matches,
    assert_raises,
    assert_equal)


class TestVirtualUtils(unittest.TestCase):
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

    @patch('apex.virtual.utils.utils')
    def test_generate_inventory(self, mock_common_utils):
        generate_inventory('target_file')

    @patch('apex.virtual.utils.utils')
    def test_generate_inventory_ha_enabled(self, mock_common_utils):
        generate_inventory('target_file', ha_enabled=True)

    @patch('apex.virtual.utils.iptc')
    @patch('apex.virtual.utils.subprocess.check_call')
    @patch('apex.virtual.utils.vbmc_lib')
    def test_host_setup(self, mock_vbmc_lib, mock_subprocess, mock_iptc):
        host_setup({'test': 2468})

    @patch('apex.virtual.utils.iptc')
    @patch('apex.virtual.utils.subprocess.check_call')
    @patch('apex.virtual.utils.vbmc_lib')
    def test_host_setup_raise_called_process_error(self, mock_vbmc_lib,
                                                   mock_subprocess, mock_iptc):
        mock_subprocess.side_effect = subprocess.CalledProcessError(1, 'cmd')
        assert_raises(subprocess.CalledProcessError, host_setup, {'test': 2468})

    @patch('apex.virtual.utils.os.path')
    @patch('apex.virtual.utils.subprocess.check_output')
    def test_virt_customize(self, mock_subprocess, mock_os_path):
        virt_customize([{'--operation': 'arg'}], 'target')

    @patch('apex.virtual.utils.subprocess.check_output')
    def test_virt_customize_file_not_found(self, mock_subprocess):
        assert_raises(FileNotFoundError,
                      virt_customize,
                      [{'--operation': 'arg'}], 'target')

    @patch('apex.virtual.utils.os.path')
    @patch('apex.virtual.utils.subprocess.check_output')
    def test_virt_customize(self, mock_subprocess, mock_os_path):
        mock_subprocess.side_effect = subprocess.CalledProcessError(1, 'cmd')
        assert_raises(subprocess.CalledProcessError,
                      virt_customize,
                      [{'--operation': 'arg'}], 'target')
