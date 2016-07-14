##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import io
# https://docs.python.org/3/library/io.html

from apex.deploy_env import DeploySettings
from apex.deploy_env import DeploySettingsException

from nose.tools import assert_equal
from nose.tools import assert_raises

deploy_files = ('deploy_settings.yaml',
                'os-nosdn-nofeature-noha.yaml',
                'os-nosdn-ovs-noha.yaml',
                'os-ocl-nofeature-ha.yaml',
                'os-odl_l2-sdnvpn-ha.yaml',
                'os-odl_l3-nofeature-ha.yaml',
                'os-nosdn-nofeature-ha.yaml',
                'os-nosdn-ovs-ha.yaml',
                'os-nosdn-performance-ha.yaml',
                'os-odl_l2-nofeature-ha.yaml',
                'os-odl_l2-sfc-noha.yaml',
                'os-onos-nofeature-ha.yaml',
                'os-onos-sfc-ha.yaml')

test_deploy_content = (
    'global_params:',
    'deploy_options: string',
    """deploy_options: string
global_params:""",
    """global_params:
deploy_options:
  error: error
""",
    """global_params:
deploy_options:
  performance: string
""",
    """global_params:
deploy_options:
  dataplane: invalid
""",
    """global_params:
deploy_options:
  performance:
    Controller:
      error: error
""",)


class TestIpUtils(object):
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

    def test_init(self):
        for f in deploy_files:
            ds = DeploySettings('../config/deploy/{}'.format(f))

    def test__validate_settings(self):
        for c in test_deploy_content:
            f = open('/tmp/apex_deploy_test_file', 'w')
            f.write(c)
            f.close()
            assert_raises(DeploySettingsException,
                          DeploySettings, '/tmp/apex_deploy_test_file')

    def test_dump_bash(self):
        # the performance file has the most use of the function
        # so using that as the test case
        ds = DeploySettings('../config/deploy/os-nosdn-performance-ha.yaml')
        assert_equal(ds.dump_bash(), None)
        assert_equal(ds.dump_bash(path='/dev/null'), None)
