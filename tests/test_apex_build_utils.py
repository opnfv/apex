##############################################################################
# Copyright (c) 2017 Feng Pan (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

from apex.build_utils import clone_fork
import git
import mock
import os


class TestBuildUtils(object):
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

    @mock.patch.object(os.path, 'exists', return_value=False)
    @mock.patch('git.Repo')
    def test_clone_fork(self, mock_git, mock_os):
        print(mock_git)
        commit = mock_git.return_value.commit.return_value
        commit.message = "Test commit message\n\n" \
                         "apex-puppet-tripleo: " \
                         "If498c41d706c8f14a5b0bbee64cb4d26cd78c2d0"
        repo = 'apex-puppet-tripleo'
        clone_fork(repo)
        commit.message = "Test commit message"
        clone_fork(repo)
