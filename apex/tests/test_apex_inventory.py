##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os

from nose.tools import (
    assert_equal,
    assert_is_instance,
    assert_raises)

from apex import Inventory
from apex.inventory.inventory import ApexInventoryException
from apex.tests.constants import (
    TEST_CONFIG_DIR,
    TEST_DUMMY_CONFIG
)

inventory_files = ('intel_pod2_settings.yaml',
                   'nokia_pod1_settings.yaml',
                   'pod_example_settings.yaml')

files_dir = os.path.join(TEST_CONFIG_DIR, 'inventory')


class TestInventory:
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

    def test_inventory_baremetal(self):
        for f in inventory_files:
            i = Inventory(os.path.join(files_dir, f))
            assert_equal(i.dump_instackenv_json(), None)
            i['nodes'][0]['arch'] = 'aarch64'
            i = Inventory(i)
            assert_equal(i['nodes'][0]['arch'], 'aarch64')

    def test_inventory_invalid_ha_count(self):
        assert_raises(ApexInventoryException, Inventory,
                      os.path.join(TEST_DUMMY_CONFIG, 'inventory-virt.yaml'),
                      virtual=True, ha=True)

    def test_inventory_valid_allinone_count(self):
        i = Inventory(os.path.join(TEST_DUMMY_CONFIG,
                                   'inventory-virt-1-node.yaml'), ha=False)
        assert_equal(list(i.get_node_counts()), [1, 0])

    def test_inventory_invalid_noha_count(self):
        assert_raises(ApexInventoryException, Inventory,
                      os.path.join(TEST_DUMMY_CONFIG,
                                   'inventory-virt-1-compute-node.yaml'),
                      virtual=True, ha=False)

    def test_inventory_virtual(self):
        i = Inventory(os.path.join(TEST_DUMMY_CONFIG, 'inventory-virt.yaml'),
                      virtual=True, ha=False)
        assert_equal(i.dump_instackenv_json(), None)

    def test_get_node_counts(self):
        i = Inventory(os.path.join(TEST_DUMMY_CONFIG, 'inventory-virt.yaml'),
                      virtual=True, ha=False)
        assert_equal(i.get_node_counts(), (1, 1))
