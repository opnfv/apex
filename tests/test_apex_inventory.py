##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import sys

from apex.inventory import Inventory
from apex.inventory import InventoryException

from nose.tools import assert_is_instance
from nose.tools import assert_raises
from nose.tools import assert_equal
from nose.tools import assert_regexp_matches
from io import StringIO

inventory_files = ('intel_pod2_settings.yaml',
                   'nokia_pod1_settings.yaml',
                   'pod_example_settings.yaml')


class TestInventory(object):
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
        for f in inventory_files:
            i = Inventory('../config/inventory/{}'.format(f))
            assert_equal(i.dump_instackenv_json(), None)

        # test virtual
        i = Inventory(i, virtual=True)
        assert_equal(i.dump_instackenv_json(), None)

        # Remove nodes to violate HA node count
        while len(i['nodes']) >= 5:
            i['nodes'].pop()
        assert_raises(InventoryException,
                      Inventory, i)

        # Remove nodes to violate non-HA node count
        while len(i['nodes']) >= 2:
            i['nodes'].pop()
        assert_raises(InventoryException,
                      Inventory, i, ha=False)

    def test_exception(sefl):
        e = InventoryException("test")
        print(e)
        assert_is_instance(e, InventoryException)

    def test_dump_bash_default(self):
        i = Inventory('../config/inventory/intel_pod2_settings.yaml')
        out = StringIO()
        sys.stdout = out
        i.dump_bash()
        output = out.getvalue().strip()
        assert_regexp_matches(output, 'root_disk_list=sda')

    def test_dump_bash_set_root_device(self):
        i = Inventory('../config/inventory/pod_example_settings.yaml')
        out = StringIO()
        sys.stdout = out
        i.dump_bash()
        output = out.getvalue().strip()
        assert_regexp_matches(output, 'root_disk_list=sdb')
