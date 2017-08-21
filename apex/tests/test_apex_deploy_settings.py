##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# https://docs.python.org/3/library/io.html
import os
import tempfile

from nose.tools import assert_equal
from nose.tools import assert_is_instance
from nose.tools import assert_raises

from apex.settings.deploy_settings import DeploySettings
from apex.settings.deploy_settings import DeploySettingsException
from apex.tests.constants import TEST_CONFIG_DIR

deploy_files = ('deploy_settings.yaml',
                'os-nosdn-nofeature-noha.yaml',
                'os-nosdn-ovs_dpdk-noha.yaml',
                'os-ocl-nofeature-ha.yaml',
                'os-odl-bgpvpn-ha.yaml',
                'os-odl-bgpvpn-noha.yaml',
                'os-odl-nofeature-ha.yaml',
                'os-nosdn-nofeature-ha.yaml',
                'os-nosdn-ovs_dpdk-ha.yaml',
                'os-nosdn-performance-ha.yaml',
                'os-odl-nofeature-ha.yaml',
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
""",
    """global_params:
deploy_options:
  performance:
    InvalidRole:
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
            ds = DeploySettings(os.path.join(TEST_CONFIG_DIR, 'deploy', f))
            ds = DeploySettings(ds)

    def test__validate_settings(self):
        for c in test_deploy_content:
            try:
                f = tempfile.NamedTemporaryFile(mode='w')
                f.write(c)
                f.flush()
                assert_raises(DeploySettingsException,
                              DeploySettings, f.name)
            finally:
                f.close()

    def test_exception(self):
        e = DeploySettingsException("test")
        print(e)
        assert_is_instance(e, DeploySettingsException)
