##############################################################################
# Copyright (c) 2017 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import subprocess
import unittest

from mock import patch
from nose import tools
from argparse import ArgumentParser

from apex.build import ApexBuildException
from apex.build import create_build_parser
from apex.build import get_cache_file
from apex.build import get_journal
from apex.build import main
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
        cls.sys_argv_debug =  ['deploy.py', '--debug']

    @classmethod
    def teardown_class(cls):
        """This method is run once for each class _after_ all tests are run"""

    def setup(self):
        """This method is run once before _each_ test method is executed"""

    def teardown(self):
        """This method is run once after _each_ test method is executed"""

    def test_create_build_parser(self):
        assert_is_instance(create_build_parser(), ArgumentParser) 

    @patch('apex.build.os.path')
    def test_get_journal_exists(self, mock_os_path):
        # setup mock
        mock_os_path.isfile.return_value = True
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
        mock_os.listdir.return_value = 'listdir is Mocked'
        unpack_cache('dest_dir', cache_dir='cache_dir')

    @patch('apex.build.create_build_parser')
    @patch('apex.build.subprocess')
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
    @patch('apex.build.subprocess')
    @patch('apex.build.os.path')
    @patch('apex.build.os')
    @patch('apex.build.utils')
    @patch('apex.build.unpack_cache')
    @patch('apex.build.build_cache')
    @patch('apex.build.prune_cache')
    @patch('apex.build.build')
    def test_main2(self, mock_build, mock_prune_cache,
                  mock_build_cache, mock_unpack_cache,
                  mock_utils, mock_os, mock_os_path,
                  mock_subprocess, mock_parser):
        #setup mock
        mbc = mock_parser.return_value        
        args = mbc.parse_args.return_value
        args.debug = True
        mock_os_path.isdir.return_value = False
        # assert
        assert_raises(ApexBuildException, main)
