##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import logging
import os

from apex.common import constants as con

SDN_FILE_MAP = {
    'opendaylight': {
        'sfc': 'opendaylight_sfc.yaml',
        'vpn': 'neutron-bgpvpn-opendaylight.yaml',
        'gluon': 'gluon.yaml',
        'vpp': {
            'odl_vpp_netvirt': 'neutron-opendaylight-netvirt-vpp.yaml',
            'default': 'neutron-opendaylight-honeycomb.yaml'
        },
        'default': 'neutron-opendaylight.yaml',
    },
    'onos': {
        'sfc': 'neutron-onos-sfc.yaml',
        'default': 'neutron-onos.yaml'
    },
    'ovn': 'neutron-ml2-ovn.yaml',
    False: {
        'vpp': 'neutron-ml2-vpp.yaml',
        'dataplane': ('ovs_dpdk', 'neutron-ovs-dpdk.yaml')
    }
}

OTHER_FILE_MAP = {
    'tacker': 'enable_tacker.yaml',
    'congress': 'enable_congress.yaml',
    'barometer': 'enable_barometer.yaml',
    'rt_kvm': 'enable_rt_kvm.yaml'
}


def build_sdn_env_list(ds, sdn_map, env_list=None):
    if env_list is None:
        env_list = list()
    for k, v in sdn_map.items():
        if ds[k] is True or ds[k] == ds['sdn_controller']:
            if isinstance(v, dict):
                env_list.append(build_sdn_env_list(ds, v))
            else:
                env_list.append(os.path.join(con.THT_DIR, v))
        elif isinstance(v, tuple):
                if ds[k] == v[0]:
                    env_list.append(os.path.join(con.THT_DIR, v[1]))
    if len(env_list) == 0:
        try:
            env_list.append(os.path.join(
                con.THT_DIR, sdn_map[ds['sdn_controller']]['default']))
        except KeyError:
            logging.warning("Unable to find default file for SDN")

    return env_list


def create_deploy_cmd(ds, env_file='opnfv-environment.yaml'):
    deploy_options = [env_file, 'network-environment.yaml']
    ds_opts = ds['deploy_options']
    deploy_options += build_sdn_env_list(ds_opts, SDN_FILE_MAP)

    # TODO(trozet): make sure rt kvm file is in tht dir
    for k, v in OTHER_FILE_MAP.items():
        if k in ds_opts and ds_opts['k']:
            deploy_options.append(os.path.join(con.THT_DIR, v))
