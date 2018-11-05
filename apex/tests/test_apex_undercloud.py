##############################################################################
# Copyright (c) 2016 Dan Radez (dradez@redhat.com) (Red Hat)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import ipaddress
import libvirt
import os
import subprocess
import unittest

from mock import patch
from mock import MagicMock

from apex.common import constants
from apex.undercloud.undercloud import Undercloud
from apex.undercloud.undercloud import ApexUndercloudException

from nose.tools import (
    assert_regexp_matches,
    assert_raises,
    assert_true,
    assert_false,
    assert_equal)


class TestUndercloud(unittest.TestCase):
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

    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_init(self, mock_get_vm, mock_create):
        Undercloud('img_path', 'tplt_path')
        mock_create.assert_called()

    @patch.object(Undercloud, '_get_vm', return_value=object())
    @patch.object(Undercloud, 'create')
    def test_init_uc_exists(self, mock_get_vm, mock_create):
        assert_raises(ApexUndercloudException,
                      Undercloud, 'img_path', 'tplt_path')

    @patch('apex.undercloud.undercloud.libvirt.open')
    @patch.object(Undercloud, 'create')
    def test_get_vm_exists(self, mock_create, mock_libvirt):
        assert_raises(ApexUndercloudException,
                      Undercloud, 'img_path', 'tplt_path')

    @patch('apex.undercloud.undercloud.libvirt.open')
    @patch.object(Undercloud, 'create')
    def test_get_vm_not_exists(self, mock_create, mock_libvirt):
        conn = mock_libvirt.return_value
        conn.lookupByName.side_effect = libvirt.libvirtError('defmsg')
        Undercloud('img_path', 'tplt_path')

    @patch('apex.undercloud.undercloud.vm_lib')
    @patch.object(Undercloud, 'inject_auth', return_value=None)
    @patch.object(Undercloud, 'setup_volumes', return_value=None)
    @patch.object(Undercloud, '_get_vm', return_value=None)
    def test_create(self, mock_get_vm, mock_setup_vols,
                    mock_inject_auth, mock_vm_lib):
        Undercloud('img_path', 'tplt_path', external_network=True)
        mock_inject_auth.assert_called()
        mock_setup_vols.assert_called()
        mock_inject_auth.assert_called()

    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_set_ip(self, mock_get_vm, mock_create):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        uc.vm = MagicMock()
        if_addrs = {'item1': {'addrs': [{'type': libvirt.VIR_IP_ADDR_TYPE_IPV4,
                                         'addr': 'ipaddress'}]},
                    'item2': {'addrs': [{'type': libvirt.VIR_IP_ADDR_TYPE_IPV4,
                                         'addr': 'ipaddress'}]}}
        uc.vm.interfaceAddresses.return_value = if_addrs
        assert_true(uc._set_ip())

    @patch('apex.undercloud.undercloud.time.sleep')
    @patch.object(Undercloud, '_set_ip', return_value=False)
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_start(self, mock_create, mock_get_vm,
                   mock_set_ip, mock_time):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        uc.vm = MagicMock()
        uc.vm.isActive.return_value = False
        mock_set_ip.return_value = True
        uc.start()

    @patch('apex.undercloud.undercloud.time.sleep')
    @patch.object(Undercloud, '_set_ip', return_value=False)
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_start_no_ip(self, mock_create, mock_get_vm,
                         mock_set_ip, mock_time):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        uc.vm = MagicMock()
        uc.vm.isActive.return_value = True
        mock_set_ip.return_value = False
        assert_raises(ApexUndercloudException, uc.start)

    @patch('apex.undercloud.undercloud.utils')
    @patch.object(Undercloud, 'generate_config', return_value={})
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_detect_nat_with_external(self, mock_create, mock_get_vm,
                                      mock_generate_config, mock_utils):
        ns = MagicMock()
        ns.enabled_network_list = ['admin', 'external']
        ns_dict = {
            'apex': MagicMock(),
            'dns-domain': 'dns',
            'networks': {'admin':
                         {'cidr': ipaddress.ip_network('192.0.2.0/24'),
                          'installer_vm': {'ip': '192.0.2.1',
                                           'vlan': 'native'},
                          'dhcp_range': ['192.0.2.15', '192.0.2.30'],
                          'gateway': '192.1.1.1',
                          },
                         'external':
                         [{'enabled': True,
                           'cidr': ipaddress.ip_network('192.168.0.0/24'),
                          'installer_vm': {'ip': '192.168.0.1',
                                           'vlan': 'native'},
                           'gateway': '192.168.0.1'
                           }]
                         }
        }
        ns.__getitem__.side_effect = ns_dict.__getitem__
        ns.__contains__.side_effect = ns_dict.__contains__

        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        assert_true(uc.detect_nat(ns))

    @patch('apex.undercloud.undercloud.utils')
    @patch.object(Undercloud, 'generate_config', return_value={})
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_detect_nat_no_external(self, mock_create, mock_get_vm,
                                    mock_generate_config, mock_utils):
        ns = MagicMock()
        ns.enabled_network_list = ['admin', 'external']
        ns_dict = {
            'apex': MagicMock(),
            'dns-domain': 'dns',
            'networks': {'admin':
                         {'cidr': ipaddress.ip_network('192.0.2.0/24'),
                          'installer_vm': {'ip': '192.0.2.1',
                                           'vlan': 'native'},
                          'dhcp_range': ['192.0.2.15', '192.0.2.30'],
                          'gateway': '192.0.2.1',
                          },
                         'external':
                         [{'enabled': False,
                           'cidr': ipaddress.ip_network('192.168.0.0/24'),
                          'installer_vm': {'ip': '192.168.0.1',
                                           'vlan': 'native'},
                           'gateway': '192.168.1.1'
                           }]
                         }
        }
        ns.__getitem__.side_effect = ns_dict.__getitem__
        ns.__contains__.side_effect = ns_dict.__contains__

        uc = Undercloud('img_path', 'tplt_path', external_network=False)
        assert_true(uc.detect_nat(ns))

    @patch('apex.undercloud.undercloud.utils')
    @patch.object(Undercloud, 'generate_config', return_value={})
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_detect_no_nat_no_external(self, mock_create, mock_get_vm,
                                       mock_generate_config, mock_utils):
        ns = MagicMock()
        ns.enabled_network_list = ['admin', 'external']
        ns_dict = {
            'apex': MagicMock(),
            'dns-domain': 'dns',
            'networks': {'admin':
                         {'cidr': ipaddress.ip_network('192.0.2.0/24'),
                          'installer_vm': {'ip': '192.0.2.1',
                                           'vlan': 'native'},
                          'dhcp_range': ['192.0.2.15', '192.0.2.30'],
                          'gateway': '192.0.2.3',
                          },
                         'external':
                         [{'enabled': False,
                           'cidr': ipaddress.ip_network('192.168.0.0/24'),
                          'installer_vm': {'ip': '192.168.0.1',
                                           'vlan': 'native'},
                           'gateway': '192.168.1.1'
                           }]
                         }
        }
        ns.__getitem__.side_effect = ns_dict.__getitem__
        ns.__contains__.side_effect = ns_dict.__contains__

        uc = Undercloud('img_path', 'tplt_path', external_network=False)
        assert_false(uc.detect_nat(ns))

    @patch('apex.undercloud.undercloud.utils')
    @patch.object(Undercloud, 'generate_config', return_value={})
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_configure(self, mock_create, mock_get_vm,
                       mock_generate_config, mock_utils):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        ns = MagicMock()
        ds = MagicMock()
        uc.configure(ns, ds, 'playbook', '/tmp/dir')

    @patch('apex.undercloud.undercloud.utils')
    @patch.object(Undercloud, 'generate_config', return_value={})
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_configure_raises(self, mock_create, mock_get_vm,
                              mock_generate_config, mock_utils):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        ns = MagicMock()
        ds = MagicMock()
        subps_err = subprocess.CalledProcessError(1, 'cmd')
        mock_utils.run_ansible.side_effect = subps_err
        assert_raises(ApexUndercloudException,
                      uc.configure, ns, ds, 'playbook', '/tmp/dir')

    @patch('apex.undercloud.undercloud.os.remove')
    @patch('apex.undercloud.undercloud.os.path')
    @patch('apex.undercloud.undercloud.shutil')
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_setup_vols(self, mock_get_vm, mock_create,
                        mock_shutil, mock_os_path, mock_os_remove):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        mock_os_path.isfile.return_value = True
        mock_os_path.exists.return_value = True
        uc.setup_volumes()
        for img_file in ('overcloud-full.vmlinuz', 'overcloud-full.initrd',
                         'undercloud.qcow2'):
            src_img = os.path.join(uc.image_path, img_file)
            dest_img = os.path.join(constants.LIBVIRT_VOLUME_PATH, img_file)
            mock_shutil.copyfile.assert_called_with(src_img, dest_img)

    @patch('apex.undercloud.undercloud.os.path')
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_setup_vols_raises(self, mock_get_vm, mock_create, mock_os_path):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        mock_os_path.isfile.return_value = False
        assert_raises(ApexUndercloudException, uc.setup_volumes)

    @patch('apex.undercloud.undercloud.virt_utils')
    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_inject_auth(self, mock_get_vm, mock_create, mock_vutils):
        uc = Undercloud('img_path', 'tplt_path', external_network=True)
        uc.root_pw = 'test'
        uc.inject_auth()
        test_ops = [{'--root-password': 'password:test'},
                    {'--run-command': 'mkdir -p /root/.ssh'},
                    {'--upload':
                     '/root/.ssh/id_rsa.pub:/root/.ssh/authorized_keys'},
                    {'--run-command': 'chmod 600 /root/.ssh/authorized_keys'},
                    {'--run-command': 'restorecon '
                                      '-R -v /root/.ssh'},
                    {'--run-command': 'id -u stack || useradd -m stack'},
                    {'--run-command': 'mkdir -p /home/stack/.ssh'},
                    {'--run-command': 'chown stack:stack /home/stack/.ssh'},
                    {'--run-command':
                     'cp /root/.ssh/authorized_keys /home/stack/.ssh/'},
                    {'--run-command':
                     'chown stack:stack /home/stack/.ssh/authorized_keys'},
                    {'--run-command':
                     'chmod 600 /home/stack/.ssh/authorized_keys'}]
        mock_vutils.virt_customize.assert_called_with(test_ops, uc.volume)

    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    def test_generate_config(self, mock_get_vm, mock_create):
        ns = MagicMock()
        ns.enabled_network_list = ['admin', 'external']
        ns_dict = {
            'apex': MagicMock(),
            'dns-domain': 'dns',
            'ntp': 'pool.ntp.org',
            'networks': {'admin':
                         {'cidr': ipaddress.ip_network('192.0.2.0/24'),
                          'installer_vm': {'ip': '192.0.2.1',
                                           'vlan': 'native'},
                          'dhcp_range': ['192.0.2.15', '192.0.2.30']
                          },
                         'external':
                         [{'enabled': True,
                           'cidr': ipaddress.ip_network('192.168.0.0/24'),
                          'installer_vm': {'ip': '192.168.0.1',
                                           'vlan': 'native'}
                           }]
                         }
        }
        ns.__getitem__.side_effect = ns_dict.__getitem__
        ns.__contains__.side_effect = ns_dict.__contains__
        ds = {'global_params': {},
              'deploy_options': {}}

        Undercloud('img_path', 'tplt_path').generate_config(ns, ds)

    @patch.object(Undercloud, '_get_vm', return_value=None)
    @patch.object(Undercloud, 'create')
    @patch('apex.undercloud.undercloud.virt_utils')
    def test_update_delorean(self, mock_vutils, mock_uc_create, mock_get_vm):
        uc = Undercloud('img_path', 'tmplt_path', external_network=True)
        uc._update_delorean_repo()
        download_cmd = (
            "curl -L -f -o "
            "/etc/yum.repos.d/deloran.repo "
            "https://trunk.rdoproject.org/centos7-{}"
            "/current-tripleo/delorean.repo".format(
                constants.DEFAULT_OS_VERSION))
        test_ops = [{'--run-command': download_cmd}]
        mock_vutils.virt_customize.assert_called_with(test_ops, uc.volume)
