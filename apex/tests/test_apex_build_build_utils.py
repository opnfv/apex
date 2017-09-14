##############################################################################
# Copyright (c) 2016 Tim Rozet (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import git
import sys

from mock import patch
from nose import tools

from apex.build import build_utils

from nose.tools import (
    assert_raises)


class TestClean(object):
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

    def test_main_wo_func_w_debug(self):
        with patch.object(build_utils.sys, 'argv', self.sys_argv_debug):
            # no func argument (clone-fork) throws sys exit
            assert_raises(SystemExit, build_utils.main)


    @patch('apex.build.build_utils.os.path')
    @patch('apex.build.build_utils.os')
    @patch('apex.build.build_utils.shutil')
    @patch('apex.build.build_utils.GerritRestAPI')
    @patch('apex.build.build_utils.git.Repo') 
    def test_main(self, mock_git_repo, mock_gerrit_api,
                  mock_shutil, mock_os, mock_path):
        with patch.object(build_utils.sys, 'argv', self.sys_argv):
            # setup mock
            x = mock_git_repo.return_value
            xx = x.commit.return_value
            xx.message = '{}: {}'.format(self.repo_name, self.change_id)
            mock_path.exists.return_value = True
            mock_path.isdir.return_value = True
            y = mock_gerrit_api.return_value
            y.get.return_value = {'status': 'TEST',
                                  'current_revision': 'revision',
                                  'revisions':
                                      {'revision': {'ref': self.commit_id}}}
            z = mock_git_repo.clone_from.return_value
            # execute
            build_utils.main()
            # check results
            mock_path.exists.assert_called_with(self.repo_name)
            mock_path.isdir.assert_called_with(self.repo_name)
            mock_shutil.rmtree.assert_called_with(self.repo_name)
            mock_git_repo.clone_from.assert_called_with(self.repo_url,
                                                        self.repo_name,
                                                        b='master')
            z.git.fetch.assert_called_with(self.repo_url, self.commit_id)
            z.git.checkout.assert_called_with('FETCH_HEAD')


    @patch('apex.build.build_utils.os.path')
    @patch('apex.build.build_utils.os')
    @patch('apex.build.build_utils.shutil')
    @patch('apex.build.build_utils.GerritRestAPI')
    @patch('apex.build.build_utils.git.Repo') 
    def test_main_MERGED(self, mock_git_repo, mock_gerrit_api,
                         mock_shutil, mock_os, mock_path):
        with patch.object(build_utils.sys, 'argv', self.sys_argv):
            # setup mock
            x = mock_git_repo.return_value
            xx = x.commit.return_value
            xx.message = '{}: {}'.format(self.repo_name, self.change_id)
            mock_path.exists.return_value = True
            mock_path.isdir.return_value = False
            y = mock_gerrit_api.return_value
            y.get.return_value = {'status': 'MERGED',
                                  'current_revision': 'revision',
                                  'revisions':
                                      {'revision': {'ref': self.commit_id}}}
            z = mock_git_repo.clone_from.return_value
            # execute
            build_utils.main()
            # check results
            mock_path.exists.assert_called_with(self.repo_name)
            mock_os.remove.assert_called_with(self.repo_name)
            mock_git_repo.clone_from.assert_called_with(self.repo_url,
                                                        self.repo_name,
                                                        b='master')
            z.git.fetch.assert_not_called
            z.git.checkout.assert_not_called
