##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os
import unittest

from apex.deployment.tripleo import ApexDeployment
from apex.settings.deploy_settings import DeploySettings
from apex.tests.constants import TEST_DUMMY_CONFIG


class TestApexDeployment(unittest.TestCase):
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

    def test_determine_patches(self):
        self.maxDiff = None
        ds_file = os.path.join(TEST_DUMMY_CONFIG, 'dummy-deploy-settings.yaml')
        ds = DeploySettings(ds_file)
        patches_file = os.path.join(TEST_DUMMY_CONFIG, 'common-patches.yaml')
        d = ApexDeployment(deploy_settings=ds, patch_file=patches_file,
                           ds_file=ds_file)
        patches = d.determine_patches()
        test_patches = {
            'undercloud':
                [{'change-id': 'I2e0a40d7902f592e4b7bd727f57048111e0bea36',
                  'project': 'openstack/tripleo-common'}],
            'overcloud':
                [{'change-id': 'Ie988ba6a2d444a614e97c0edf5fce24b23970310',
                  'project': 'openstack/puppet-tripleo'}]
        }
        self.assertDictEqual(patches, test_patches)
