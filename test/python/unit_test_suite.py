__author__ = 'spisarski'

import unittest

from tests import file_utils_tests
from openstack.tests import create_image_tests
from openstack.tests import neutron_utils_tests
from openstack.tests import create_network_tests
from openstack.tests import nova_utils_tests
from openstack.tests import create_keypairs_tests
from openstack.tests import create_instance_tests
from provisioning.tests import ansible_utils_tests

unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(file_utils_tests))
unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(create_image_tests))
unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(neutron_utils_tests))
unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(create_network_tests))
unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(nova_utils_tests))
unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(create_keypairs_tests))
unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(create_instance_tests))
unittest.TextTestRunner().run(unittest.TestLoader().loadTestsFromModule(ansible_utils_tests))