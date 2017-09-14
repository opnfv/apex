##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os
import subprocess
import unittest

from mock import patch
from mock import mock_open
from argparse import ArgumentParser

from apex.build import ApexBuildException
from apex.build import build
from apex.build import build_cache
from apex.build import create_build_parser
from apex.build import get_cache_file
from apex.build import get_journal
from apex.build import main
from apex.build import prune_cache
from apex.build import unpack_cache

from nose.tools import (
    assert_raises,
    assert_is_instance)


class TestBuild(unittest.TestCase):
    @classmethod
    def setup_class(cls):
        """This method is run once for each class before any tests are run"""
        cls.repo_name = 'test_repo'
        cls.repo_url = 'https://gerrit.opnfv.org/gerrit/' + cls.repo_name
        cls.change_id = 'I5c1b3ded249c4e3c558be683559e03deb27721b8'
        cls.commit_id = '8669c687a75a00106b055add49b82fee826b8fe8'
        cls.sys_argv = ['deploy.py', 'clone-fork', '-r', cls.repo_name]
        cls.sys_argv_debug = ['deploy.py', '--debug']

    @classmethod
    def teardown_class(cls):
        """This method is run once for each class _after_ all tests are run"""

    def setup(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_create_build_parser(self):
        assert_is_instance(create_build_parser(), ArgumentParser)

    @patch('apex.build.yaml')
    @patch('apex.build.os.path')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_get_journal_exists(self, mock_os_path, mock_yaml):
        # setup mock
        mock_os_path.isfile.return_value = True
        mock_yaml.safe_load.return_value = ['a', 'list']
        # execute
        get_journal('test_dir')
        # assert
        mock_os_path.isfile.assert_called_with('test_dir/cache_journal.yaml')

    @patch('apex.build.os.path')
    def test_get_journal_notexist(self, mock_os_path):
        # setup mock
        mock_os_path.isfile.return_value = False
        # execute
        get_journal('test_dir')

    @patch('apex.build.os.path')
    @patch('apex.build.get_journal')
    def test_get_cache_file(self, mock_get_journal, mock_os_path):
        mock_get_journal.return_value = ['journal_contents']
        mock_os_path.isfile.return_value = True
        get_cache_file('test_dir')

    def test_unpack_cache_no_cache_dir(self):
        unpack_cache('dest_dir', cache_dir=None)

    @patch('apex.build.os.path')
    def test_unpack_cache_not_isdir(self, mock_os_path):
        mock_os_path.isdir.return_value = False
        unpack_cache('dest_dir', cache_dir='cache_dir')

    @patch('apex.build.get_cache_file')
    @patch('apex.build.os.path')
    def test_unpack_cache_cache_file_none(self, mock_os_path, mock_cache_file):
        mock_os_path.isdir.return_value = True
        mock_cache_file.return_value = None
        unpack_cache('dest_dir', cache_dir='cache_dir')

    @patch('apex.build.subprocess.check_call')
    @patch('apex.build.get_cache_file')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    def test_unpack_cache_tar_failure(self, mock_os, mock_os_path,
                                      mock_cache_file,
                                      mock_subprocess):
        mock_os_path.isdir.return_value = True
        mock_cache_file.return_value = 'cache_file'
        mock_os_path.exists.return_value = False
        mock_subprocess.side_effect = subprocess.CalledProcessError(1, 'cmd')
        unpack_cache('dest_dir', cache_dir='cache_dir')

    @patch('apex.build.subprocess')
    @patch('apex.build.get_cache_file')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    def test_unpack_cache_cache_dest_not_exist(self, mock_os, mock_os_path,
                                               mock_cache_file,
                                               mock_subprocess):
        mock_os_path.isdir.return_value = True
        mock_cache_file.return_value = 'cache_file'
        mock_os_path.exists.return_value = False
        mock_os.listdir.return_value = ['listdir', 'is', 'Mocked']
        unpack_cache('dest_dir', cache_dir='cache_dir')

    @patch('apex.build.subprocess')
    def test_build(self, mock_subprocess):
        build('build_root', None)

    @patch('apex.build.subprocess.check_call')
    def test_build_check_call_raises(self, mock_subprocess):
        mock_subprocess.side_effect = subprocess.CalledProcessError('cmd', 1)
        assert_raises(subprocess.CalledProcessError, build, 'build_root', None)

    @patch('apex.build.subprocess.check_output')
    @patch('apex.build.subprocess.check_call')
    def test_build_check_output_raises(self, mock_check_call, mock_subprocess):
        mock_subprocess.side_effect = subprocess.CalledProcessError('cmd', 1)
        assert_raises(subprocess.CalledProcessError, build, 'build_root', None)

    @patch('apex.build.subprocess')
    def test_build_rpms(self, mock_subprocess):
        build('build_root', 'v123', rpms=True)

    @patch('apex.build.subprocess')
    def test_build_iso(self, mock_subprocess):
        build('build_root', 'v123', iso=True)

    def test_build_cache_none(self):
        build_cache('cache_source', None)

    @patch('apex.build.get_journal')
    @patch('apex.build.yaml')
    @patch('apex.build.os')
    @patch('apex.build.subprocess')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_build_cache(self, mock_subprocess, mock_os,
                         mock_yaml, mock_get_journal):
        build_cache('cache_source', 'cache_dir')
        #    assert open("path/to/open").read() == "data"
        #    mock_file.assert_called_with("path/to/open")

    @patch('apex.build.get_journal')
    @patch('apex.build.yaml')
    @patch('apex.build.os')
    @patch('apex.build.subprocess')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_build_cache_get_journal_none(self, mock_subprocess, mock_os,
                                          mock_yaml, mock_get_journal):
        mock_get_journal.return_value = None
        build_cache('cache_source', 'cache_dir')

    @patch('apex.build.get_journal')
    @patch('apex.build.yaml')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    @patch('apex.build.subprocess.check_call')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_build_cache_tar_fails(self, mock_subprocess, mock_os,
                                   mock_os_path, mock_yaml, mock_get_journal):
        mock_subprocess.side_effect = BaseException()
        mock_os_path.isfile.return_value = True
        assert_raises(BaseException, build_cache, 'cache_source', 'cache_dir')

    @patch('apex.build.get_journal')
    @patch('apex.build.yaml')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    @patch('apex.build.subprocess.check_call')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_build_cache_cache_full_path_false(self, mock_subprocess, mock_os,
                                               mock_os_path, mock_yaml,
                                               mock_get_journal):
        mock_os_path.isfile.return_value = False
        build_cache('cache_source', 'cache_dir')

    def test_prune_cache_none(self):
        prune_cache(None)

    @patch('apex.build.get_journal')
    def test_prune_cache_empty_journal(self, mock_get_journal):
        mock_get_journal.return_value = []
        prune_cache('not-none')

    @patch('apex.build.get_journal')
    @patch('apex.build.yaml')
    @patch('apex.build.os')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_prune_cache_os_remove_error(self, mock_os, mock_yaml,
                                         mock_get_journal):
        # setup Mock
        mock_get_journal.return_value = ['more', 'than', 'two']
        rm = mock_os.remove
        rm.side_effect = OSError()
        # execute
        prune_cache('not-none')

    @patch('apex.build.get_journal')
    @patch('apex.build.yaml')
    @patch('apex.build.os')
    @patch('builtins.open', mock_open(read_data=None), create=True)
    def test_prune_cache(self, mock_os, mock_yaml, mock_get_journal):
        # setup Mock
        mock_get_journal.return_value = ['more', 'than', 'two']
        # execute
        prune_cache('not-none')

    @patch('apex.build.create_build_parser')
    @patch('apex.build.subprocess.check_output')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    @patch('apex.build.utils')
    @patch('apex.build.unpack_cache')
    @patch('apex.build.build_cache')
    @patch('apex.build.prune_cache')
    @patch('apex.build.build')
    def test_main(self, mock_build, mock_prune_cache,
                  mock_build_cache, mock_unpack_cache,
                  mock_utils, mock_os, mock_os_path,
                  mock_subprocess, mock_parser):
        # setup mock
        mbc = mock_parser.return_value
        args = mbc.parse_args.return_value
        args.debug = False
        mock_os_path.isdir.return_value = True
        # execute
        main()
        # assert
        # TODO

    @patch('apex.build.create_build_parser')
    @patch('apex.build.subprocess.check_output')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    @patch('apex.build.utils')
    @patch('apex.build.unpack_cache')
    @patch('apex.build.build_cache')
    @patch('apex.build.prune_cache')
    @patch('apex.build.build')
    def test_main_throw_build_except(self, mock_build, mock_prune_cache,
                                     mock_build_cache, mock_unpack_cache,
                                     mock_utils, mock_os, mock_os_path,
                                     mock_subprocess, mock_parser):
        # setup mock
        mbc = mock_parser.return_value
        args = mbc.parse_args.return_value
        args.debug = True
        mock_os_path.isdir.return_value = False
        # execute and assert
        assert_raises(ApexBuildException, main)

    @patch('apex.build.create_build_parser')
    @patch('apex.build.subprocess.check_output')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    @patch('apex.build.utils')
    @patch('apex.build.unpack_cache')
    @patch('apex.build.build_cache')
    @patch('apex.build.prune_cache')
    @patch('apex.build.build')
    def test_main_throw_subprocess_except(self, mock_build, mock_prune_cache,
                                          mock_build_cache, mock_unpack_cache,
                                          mock_utils, mock_os, mock_os_path,
                                          mock_subprocess, mock_parser):
        # setup mock
        mbc = mock_parser.return_value
        args = mbc.parse_args.return_value
        args.debug = False
        mock_os_path.isdir.return_value = True
        mock_subprocess.side_effect = subprocess.CalledProcessError('cmd', 1)
        # execute and assert
        assert_raises(subprocess.CalledProcessError, main)
