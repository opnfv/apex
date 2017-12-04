##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import git
import os
import unittest

from mock import patch

from apex import build_utils
from apex.tests import constants as con

from nose.tools import (
    assert_is_instance,
    assert_raises)


class TestBuildUtils(unittest.TestCase):
    @classmethod
    def setup_class(cls):
        """This method is run once for each class before any tests are run"""
        cls.repo_name = 'test_repo'
        cls.repo_url = 'https://gerrit.opnfv.org/gerrit'
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

    def test_main_wo_func_w_debug(self):
        with patch.object(build_utils.sys, 'argv', self.sys_argv_debug):
            # no func argument (clone-fork) throws sys exit
            assert_raises(SystemExit, build_utils.main)

    @patch('apex.build_utils.get_parser')
    @patch('apex.build_utils.os.path')
    @patch('apex.build_utils.os')
    @patch('apex.build_utils.shutil')
    @patch('apex.build_utils.GerritRestAPI')
    @patch('apex.build_utils.git.Repo')
    def test_clone_fork(self, mock_git_repo, mock_gerrit_api,
                        mock_shutil, mock_os, mock_path, mock_get_parser):
        # setup mock
        args = mock_get_parser.parse_args.return_value
        args.repo = self.repo_name
        args.url = self.repo_url
        args.branch = 'master'
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
        build_utils.clone_fork(args)
        # check results
        mock_path.exists.assert_called_with(self.repo_name)
        mock_path.isdir.assert_called_with(self.repo_name)
        mock_shutil.rmtree.assert_called_with(self.repo_name)
        mock_git_repo.clone_from.assert_called_with('{}/{}'.
                                                    format(self.repo_url,
                                                           self.repo_name),
                                                    self.repo_name,
                                                    b='master')
        z.git.fetch.assert_called_with('{}/{}'.format(self.repo_url,
                                                      self.repo_name),
                                       self.commit_id)
        z.git.checkout.assert_called_with('FETCH_HEAD')

    @patch('apex.build_utils.get_parser')
    @patch('apex.build_utils.os.path')
    @patch('apex.build_utils.os')
    @patch('apex.build_utils.shutil')
    @patch('apex.build_utils.GerritRestAPI')
    @patch('apex.build_utils.git.Repo')
    def test_clone_fork_MERGED(self, mock_git_repo, mock_gerrit_api,
                               mock_shutil, mock_os, mock_path,
                               mock_get_parser):
        # setup mock
        args = mock_get_parser.parse_args.return_value
        args.repo = self.repo_name
        args.url = self.repo_url
        args.branch = 'master'
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
        build_utils.clone_fork(args)
        # check results
        mock_path.exists.assert_called_with(self.repo_name)
        mock_os.remove.assert_called_with(self.repo_name)
        mock_git_repo.clone_from.assert_called_with('{}/{}'.
                                                    format(self.repo_url,
                                                           self.repo_name),
                                                    self.repo_name, b='master')
        z.git.fetch.assert_not_called
        z.git.checkout.assert_not_called

    @patch('apex.build_utils.get_parser')
    @patch('apex.build_utils.GerritRestAPI')
    @patch('apex.build_utils.git.Repo')
    def test_clone_fork_invalid_git_repo(self, mock_git_repo,
                                         mock_gerrit_api, mock_get_parser):
        # setup mock
        args = mock_get_parser.parse_args.return_value
        args.repo = self.repo_name
        args.url = self.repo_url
        args.branch = 'master'
        mock_git_repo.side_effect = git.exc.InvalidGitRepositoryError()
        build_utils.clone_fork(args)

    @patch('apex.build_utils.get_parser')
    @patch('apex.build_utils.GerritRestAPI')
    @patch('apex.build_utils.git.Repo')
    def test_clone_fork_raises_key_error(self, mock_git_repo,
                                         mock_gerrit_api, mock_get_parser):
        # setup mock
        args = mock_get_parser.parse_args.return_value
        args.repo = self.repo_name
        args.url = self.repo_url
        args.branch = 'master'
        x = mock_git_repo.return_value
        xx = x.commit.return_value
        xx.message = '{}: {}'.format(self.repo_name, self.change_id)
        y = mock_gerrit_api.return_value
        y.get.return_value = {}
        # execute & assert
        assert_raises(KeyError, build_utils.clone_fork, args)

    def test_get_parser(self):
        assert_is_instance(build_utils.get_parser(), argparse.ArgumentParser)

    @patch('apex.build_utils.get_parser')
    def test_main(self, mock_get_parser):
        with patch.object(build_utils.sys, 'argv', self.sys_argv):
            build_utils.main()

    @patch('apex.build_utils.get_parser')
    def test_main_debug(self, mock_get_parser):
        with patch.object(build_utils.sys, 'argv', self.sys_argv_debug):
            build_utils.main()

    def test_strip_patch_sections(self):
        with open(os.path.join(con.TEST_DUMMY_CONFIG, '98faaca.diff')) as fh:
            dummy_patch = fh.read()
        tmp_patch = build_utils.strip_patch_sections(dummy_patch)
        self.assertNotRegex(tmp_patch, 'releasenotes')
        self.assertNotRegex(tmp_patch, 'Minor update ODL steps')
        self.assertNotRegex(tmp_patch, 'Steps of upgrade are as follows')
        self.assertNotRegex(tmp_patch, 'Steps invlolved in level 2 update')

    def test_strip_no_patch_sections(self):
        with open(os.path.join(con.TEST_DUMMY_CONFIG, '98faaca.diff')) as fh:
            dummy_patch = fh.read()
        tmp_patch = build_utils.strip_patch_sections(dummy_patch,
                                                     sections=[])
        self.assertEqual(dummy_patch, tmp_patch)
