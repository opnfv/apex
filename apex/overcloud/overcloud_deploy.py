##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import base64
import fileinput
import logging
import os
import re
import shutil
import uuid
import struct
import time

from apex.common import constants as con
from apex.common.exceptions import ApexDeployException
from apex.common import parsers
from apex.virtual import virtual_utils as virt_utils
from cryptography.hazmat.primitives import serialization as \
    crypto_serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend as \
    crypto_default_backend


SDN_FILE_MAP = {
    'opendaylight': {
        'sfc': 'neutron-sfc-opendaylight.yaml',
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

OVS_PERF_MAP = {
    'HostCpusList': 'dpdk_cores',
    'NeutronDpdkCoreList': 'pmd_cores',
    'NeutronDpdkSocketMemory': 'socket_memory',
    'NeutronDpdkMemoryChannels': 'memory_channels'
}

OVS_NSH_KMOD_RPM = "openvswitch-kmod-2.6.1-1.el7.centos.x86_64.rpm"
OVS_NSH_RPM = "openvswitch-2.6.1-1.el7.centos.x86_64.rpm"
ODL_NETVIRT_VPP_RPM = "/root/opendaylight-7.0.0-0.1.20170531snap665.el7" \
                      ".noarch.rpm"


def build_sdn_env_list(ds, sdn_map, env_list=None):
    if env_list is None:
        env_list = list()
    for k, v in sdn_map.items():
        if ds['sdn_controller'] == k or (k in ds and ds[k] is True):
            if isinstance(v, dict):
                env_list.extend(build_sdn_env_list(ds, v))
            else:
                env_list.append(os.path.join(con.THT_ENV_DIR, v))
        elif isinstance(v, tuple):
                if ds[k] == v[0]:
                    env_list.append(os.path.join(con.THT_ENV_DIR, v[1]))
    if len(env_list) == 0:
        try:
            env_list.append(os.path.join(
                con.THT_ENV_DIR, sdn_map['default']))
        except KeyError:
            logging.warning("Unable to find default file for SDN")

    return env_list


def create_deploy_cmd(ds, ns, inv, tmp_dir,
                      virtual, env_file='opnfv-environment.yaml'):

    logging.info("Creating deployment command")
    deploy_options = [env_file, 'network-environment.yaml']
    ds_opts = ds['deploy_options']
    deploy_options += build_sdn_env_list(ds_opts, SDN_FILE_MAP)

    # TODO(trozet): make sure rt kvm file is in tht dir
    for k, v in OTHER_FILE_MAP.items():
        if k in ds_opts and ds_opts[k]:
            deploy_options.append(os.path.join(con.THT_ENV_DIR, v))

    if ds_opts['ceph']:
        prep_storage_env(ds, tmp_dir)
        deploy_options.append(os.path.join(con.THT_ENV_DIR,
                                           'storage-environment.yaml'))
    if ds['global_params']['ha_enabled']:
        deploy_options.append(os.path.join(con.THT_ENV_DIR,
                                           'puppet-pacemaker.yaml'))

    if virtual:
        deploy_options.append('virtual-environment.yaml')
    else:
        deploy_options.append('baremetal-environment.yaml')

    nodes = inv['nodes']
    num_control = 0
    num_compute = 0
    for node in nodes:
        if 'profile:control' in node['capabilities']:
            num_control += 1
        elif 'profile:compute' in node['capabilities']:
            num_compute += 1
        else:
            # TODO(trozet) do we want to allow capabilities to not exist?
            logging.error("Every node must include a 'capabilities' key "
                          "tagged with either 'profile:control' or "
                          "'profile:compute'")
            raise ApexDeployException("Node missing capabilities "
                                      "key: {}".format(node))
    if num_control == 0 or num_compute == 0:
        logging.error("Detected 0 control or compute nodes.  Control nodes: "
                      "{}, compute nodes{}".format(num_control, num_compute))
        raise ApexDeployException("Invalid number of control or computes")
    elif num_control > 1 and not ds['global_params']['ha_enabled']:
        num_control = 1
    cmd = "openstack overcloud deploy --templates --timeout {} " \
          "--libvirt-type kvm".format(con.DEPLOY_TIMEOUT)
    # build cmd env args
    for option in deploy_options:
        cmd += " -e {}".format(option)
    cmd += " --ntp-server {}".format(ns['ntp'][0])
    cmd += " --control-scale {}".format(num_control)
    cmd += " --compute-scale {}".format(num_compute)
    cmd += ' --control-flavor control --compute-flavor compute'
    logging.info("Deploy command set: {}".format(cmd))

    with open(os.path.join(tmp_dir, 'deploy_command'), 'w') as fh:
        fh.write(cmd)
    return cmd


def prep_image(ds, img, tmp_dir, root_pw=None):
    """
    Locates sdn image and preps for deployment.
    :param ds: deploy settings
    :param img: sdn image
    :param tmp_dir: dir to store modified sdn image
    :param root_pw: password to configure for overcloud image
    :return: None
    """
    # TODO(trozet): Come up with a better way to organize this logic in this
    # function
    logging.info("Preparing image: {} for deployment".format(img))
    if not os.path.isfile(img):
        logging.error("Missing SDN image {}".format(img))
        raise ApexDeployException("Missing SDN image file: {}".format(img))

    ds_opts = ds['deploy_options']
    virt_cmds = list()
    sdn = ds_opts['sdn_controller']
    # we need this due to rhbz #1436021
    # fixed in systemd-219-37.el7
    if sdn is not False:
        logging.info("Neutron openvswitch-agent disabled")
        virt_cmds.extend([{
            con.VIRT_RUN_CMD:
                "rm -f /etc/systemd/system/multi-user.target.wants/"
                "neutron-openvswitch-agent.service"},
            {
            con.VIRT_RUN_CMD:
                "rm -f /usr/lib/systemd/system/neutron-openvswitch-agent"
                ".service"
        }])

    if ds_opts['vpn']:
        virt_cmds.append({con.VIRT_RUN_CMD: "systemctl enable zrpcd"})
        logging.info("ZRPC and Quagga enabled")

    dataplane = ds_opts['dataplane']
    if dataplane == 'ovs_dpdk' or dataplane == 'fdio':
        logging.info("Enabling kernel modules for dpdk")
        # file to module mapping
        uio_types = {
            os.path.join(tmp_dir, 'vfio_pci.modules'): 'vfio_pci',
            os.path.join(tmp_dir, 'uio_pci_generic.modules'): 'uio_pci_generic'
        }
        for mod_file, mod in uio_types.items():
            with open(mod_file, 'w') as fh:
                fh.write('#!/bin/bash\n')
                fh.write('exec /sbin/modprobe {}'.format(mod))
                fh.close()

            virt_cmds.extend([
                {con.VIRT_UPLOAD: "{}:/etc/sysconfig/modules/".format(
                    mod_file)},
                {con.VIRT_RUN_CMD: "chmod 0755 /etc/sysconfig/modules/"
                                   "{}".format(os.path.basename(mod_file))}
            ])
    if root_pw:
        pw_op = "password:{}".format(root_pw)
        virt_cmds.append({con.VIRT_PW: pw_op})
    if ds_opts['sfc'] and dataplane == 'ovs':
        virt_cmds.extend([
            {con.VIRT_RUN_CMD: "yum -y install "
                               "/root/ovs/rpm/rpmbuild/RPMS/x86_64/"
                               "{}".format(OVS_NSH_KMOD_RPM)},
            {con.VIRT_RUN_CMD: "yum downgrade -y "
                               "/root/ovs/rpm/rpmbuild/RPMS/x86_64/"
                               "{}".format(OVS_NSH_RPM)}
        ])
    if dataplane == 'fdio':
        # Patch neutron with using OVS external interface for router
        # and add generic linux NS interface driver
        virt_cmds.append(
            {con.VIRT_RUN_CMD: "cd /usr/lib/python2.7/site-packages && patch "
                               "-p1 < neutron-patch-NSDriver.patch"})

    if sdn == 'opendaylight':
        if ds_opts['odl_version'] != con.DEFAULT_ODL_VERSION:
            virt_cmds.extend([
                {con.VIRT_RUN_CMD: "yum -y remove opendaylight"},
                {con.VIRT_RUN_CMD: "yum -y install /root/{}/*".format(
                    ds_opts['odl_version'])},
                {con.VIRT_RUN_CMD: "rm -rf /etc/puppet/modules/opendaylight"},
                {con.VIRT_RUN_CMD: "cd /etc/puppet/modules && tar xzf "
                                   "/root/puppet-opendaylight-"
                                   "{}.tar.gz".format(ds_opts['odl_version'])}
            ])
        elif sdn == 'opendaylight' and 'odl_vpp_netvirt' in ds_opts \
                and ds_opts['odl_vpp_netvirt']:
            virt_cmds.extend([
                {con.VIRT_RUN_CMD: "yum -y remove opendaylight"},
                {con.VIRT_RUN_CMD: "yum -y install /root/{}/*".format(
                    ODL_NETVIRT_VPP_RPM)}
            ])

    if sdn == 'ovn':
        virt_cmds.extend([
            {con.VIRT_RUN_CMD: "cd /root/ovs28 && yum update -y "
                               "*openvswitch*"},
            {con.VIRT_RUN_CMD: "cd /root/ovs28 && yum downgrade -y "
                               "*openvswitch*"}
        ])

    tmp_oc_image = os.path.join(tmp_dir, 'overcloud-full.qcow2')
    shutil.copyfile(img, tmp_oc_image)
    logging.debug("Temporary overcloud image stored as: {}".format(
        tmp_oc_image))
    virt_utils.virt_customize(virt_cmds, tmp_oc_image)
    logging.info("Overcloud image customization complete")


def make_ssh_key():
    """
    Creates public and private ssh keys with 1024 bit RSA encryption
    :return: private, public key
    """
    key = rsa.generate_private_key(
        backend=crypto_default_backend(),
        public_exponent=65537,
        key_size=1024
    )

    private_key = key.private_bytes(
        crypto_serialization.Encoding.PEM,
        crypto_serialization.PrivateFormat.PKCS8,
        crypto_serialization.NoEncryption())
    public_key = key.public_key().public_bytes(
        crypto_serialization.Encoding.OpenSSH,
        crypto_serialization.PublicFormat.OpenSSH
    )
    pub_key = re.sub('ssh-rsa\s*', '', public_key.decode('utf-8'))
    return private_key.decode('utf-8'), pub_key


def prep_env(ds, ns, opnfv_env, net_env, tmp_dir):
    """
    Creates modified opnfv/network environments for deployment
    :param ds: deploy settings
    :param ns: network settings
    :param opnfv_env: file path for opnfv-environment file
    :param net_env: file path for network-environment file
    :param tmp_dir: Apex tmp dir
    :return:
    """

    logging.info("Preparing opnfv-environment and network-environment files")
    ds_opts = ds['deploy_options']
    tmp_opnfv_env = os.path.join(tmp_dir, os.path.basename(opnfv_env))
    shutil.copyfile(opnfv_env, tmp_opnfv_env)
    tenant_nic_map = ns['networks']['tenant']['nic_mapping']
    tenant_ctrl_nic = tenant_nic_map['controller']['members'][0]
    tenant_comp_nic = tenant_nic_map['compute']['members'][0]

    # SSH keys
    private_key, public_key = make_ssh_key()

    # Make easier/faster variables to index in the file editor
    if 'performance' in ds_opts:
        perf = True
        # vpp
        if 'vpp' in ds_opts['performance']['Compute']:
            perf_vpp_comp = ds_opts['performance']['Compute']['vpp']
        else:
            perf_vpp_comp = None
        if 'vpp' in ds_opts['performance']['Controller']:
            perf_vpp_ctrl = ds_opts['performance']['Controller']['vpp']
        else:
            perf_vpp_ctrl = None

        # ovs
        if 'ovs' in ds_opts['performance']['Compute']:
            perf_ovs_comp = ds_opts['performance']['Compute']['ovs']
        else:
            perf_ovs_comp = None

        # kernel
        if 'kernel' in ds_opts['performance']['Compute']:
            perf_kern_comp = ds_opts['performance']['Compute']['kernel']
        else:
            perf_kern_comp = None
    else:
        perf = False

    # Modify OPNFV environment
    # TODO: Change to build a dict and outputing yaml rather than parsing
    for line in fileinput.input(tmp_opnfv_env, inplace=True):
        line = line.strip('\n')
        output_line = line
        if 'CloudDomain' in line:
            output_line = "  CloudDomain: {}".format(ns['domain_name'])
        elif 'replace_private_key' in line:
            output_line = "      key: '{}'".format(private_key)
        elif 'replace_public_key' in line:
            output_line = "      key: '{}'".format(public_key)

        if ds_opts['sdn_controller'] == 'opendaylight' and \
                'odl_vpp_routing_node' in ds_opts and ds_opts[
                'odl_vpp_routing_node'] != 'dvr':
            if 'opendaylight::vpp_routing_node' in line:
                output_line = ("    opendaylight::vpp_routing_node: ${}.${}"
                               .format(ds_opts['odl_vpp_routing_node'],
                                       ns['domain_name']))
            elif 'ControllerExtraConfig' in line:
                output_line = ("  ControllerExtraConfig:\n    "
                               "tripleo::profile::base::neutron::agents::"
                               "honeycomb::interface_role_mapping:"
                               " ['{}:tenant-interface]'"
                               .format(tenant_ctrl_nic))
            elif 'NovaComputeExtraConfig' in line:
                output_line = ("  NovaComputeExtraConfig:\n    "
                               "tripleo::profile::base::neutron::agents::"
                               "honeycomb::interface_role_mapping:"
                               " ['{}:tenant-interface]'"
                               .format(tenant_comp_nic))
        elif not ds_opts['sdn_controller'] and ds_opts['dataplane'] == 'fdio':
            if 'NeutronVPPAgentPhysnets' in line:
                output_line = ("  NeutronVPPAgentPhysnets: 'datacentre:{}'".
                               format(tenant_ctrl_nic))

        if perf:
            for role in 'NovaCompute', 'Controller':
                if role == 'NovaCompute':
                    perf_opts = perf_vpp_comp
                else:
                    perf_opts = perf_vpp_ctrl
                cfg = "{}ExtraConfig".format(role)
                if cfg in line and perf_opts:
                    perf_line = ''
                    if 'main-core' in perf_opts:
                        perf_line += ("\n    fdio::vpp_cpu_main_core: '{}'"
                                      .format(perf_opts['main-core']))
                    if 'corelist-workers' in perf_opts:
                        perf_line += ("\n    "
                                      "fdio::vpp_cpu_corelist_workers: '{}'"
                                      .format(perf_opts['corelist-workers']))
                    if perf_line:
                        output_line = ("  {}:{}".format(cfg, perf_line))

            # kernel args
            # (FIXME) use compute's kernel settings for all nodes for now.
            if 'ComputeKernelArgs' in line and perf_kern_comp:
                kernel_args = ''
                for k, v in perf_kern_comp.items():
                    kernel_args += "{}={} ".format(k, v)
                if kernel_args:
                    output_line = "  ComputeKernelArgs: '{}'".\
                        format(kernel_args)
            if ds_opts['dataplane'] == 'ovs_dpdk' and perf_ovs_comp:
                for k, v in OVS_PERF_MAP.items():
                    if k in line and v in perf_ovs_comp:
                        output_line = "  {}: '{}'".format(k, perf_ovs_comp[v])

        print(output_line)

    logging.info("opnfv-environment file written to {}".format(tmp_opnfv_env))

    # Modify Network environment
    for line in fileinput.input(net_env, inplace=True):
        line = line.strip('\n')
        if 'ComputeExtraConfigPre' in line and \
                ds_opts['dataplane'] == 'ovs_dpdk':
            print('  OS::TripleO::ComputeExtraConfigPre: '
                      './ovs-dpdk-preconfig.yaml')
        elif perf and perf_kern_comp:
            if 'resource_registry' in line:
                print("resource_registry:\n"
                      "  OS::TripleO::NodeUserData: first-boot.yaml")
            elif 'NovaSchedulerDefaultFilters' in line:
                print("  NovaSchedulerDefaultFilters: 'RamFilter,"
                      "ComputeFilter,AvailabilityZoneFilter,"
                      "ComputeCapabilitiesFilter,ImagePropertiesFilter,"
                      "NUMATopologyFilter'")
            else:
                print(line)
        else:
            print(line)

    logging.info("network-environment file written to {}".format(net_env))


def generate_ceph_key():
    key = os.urandom(16)
    header = struct.pack('<hiih', 1, int(time.time()), 0, len(key))
    return base64.b64encode(header + key)


def prep_storage_env(ds, tmp_dir):
    """
    Creates storage environment file for deployment.  Source file is copied by
    undercloud playbook to host.
    :param ds:
    :param tmp_dir:
    :return:
    """
    ds_opts = ds['deploy_options']
    storage_file = os.path.join(tmp_dir, 'storage-environment.yaml')
    if not os.path.isfile(storage_file):
        logging.error("storage-environment file is not in tmp directory: {}. "
                      "Check if file was copied from "
                      "undercloud".format(tmp_dir))
        raise ApexDeployException("storage-environment file not copied from "
                                  "undercloud")
    for line in fileinput.input(storage_file, inplace=True):
        line = line.strip('\n')
        if 'CephClusterFSID' in line:
            print("  CephClusterFSID: {}".format(str(uuid.uuid4())))
        elif 'CephMonKey' in line:
            print("  CephMonKey: {}".format(generate_ceph_key().decode(
                'utf-8')))
        elif 'CephAdminKey' in line:
            print("  CephAdminKey: {}".format(generate_ceph_key().decode(
                'utf-8')))
        else:
            print(line)
    if 'ceph_device' in ds_opts and ds_opts['ceph_device']:
        with open(storage_file, 'a') as fh:
            fh.write('  ExtraConfig:\n')
            fh.write("    ceph::profile::params::osds:{{{}:{{}}}}\n".format(
                ds_opts['ceph_device']
            ))


def external_network_cmds(ns):
    """
    Generates external network openstack commands
    :param ns: network settings
    :return: list of commands to configure external network
    """
    if 'external' in ns.enabled_network_list:
        net_config = ns['networks']['external'][0]
        external = True
        pool_start, pool_end = net_config['floating_ip_range']
    else:
        net_config = ns['networks']['admin']
        external = False
        pool_start, pool_end = ns['apex']['networks']['admin'][
            'introspection_range']
    nic_config = net_config['nic_mapping']
    gateway = net_config['gateway']
    cmds = list()
    # create network command
    if nic_config['compute']['vlan'] == 'native':
        ext_type = 'flat'
    else:
        ext_type = "vlan --provider-segment {}".format(nic_config[
                                                       'compute']['vlan'])
    cmds.append("openstack network create external --project service "
                "--external --provider-network-type {} "
                "--provider-physical-network datacentre".format(ext_type))
    # create subnet command
    cidr = net_config['cidr']
    subnet_cmd = "openstack subnet create external-subnet --project " \
                 "service --network external --no-dhcp --gateway {} " \
                 "--allocation-pool start={},end={} --subnet-range " \
                 "{}".format(gateway, pool_start, pool_end, str(cidr))
    if external and cidr.version == 6:
        subnet_cmd += ' --ip-version 6 --ipv6-ra-mode slaac ' \
                      '--ipv6-address-mode slaac'
    cmds.append(subnet_cmd)
    logging.debug("Neutron external network commands determined "
                  "as: {}".format(cmds))
    return cmds


def create_congress_cmds(overcloud_file):
    drivers = ['nova', 'neutronv2', 'cinder', 'glancev2', 'keystone', 'doctor']
    overcloudrc = parsers.parse_overcloudrc(overcloud_file)
    logging.info("Creating congress commands")
    try:
        ds_cfg = [
            "username={}".format(overcloudrc['OS_USERNAME']),
            "tenant_name={}".format(overcloudrc['OS_PROJECT_NAME']),
            "password={}".format(overcloudrc['OS_PASSWORD']),
            "auth_url={}".format(overcloudrc['OS_AUTH_URL'])
        ]
    except KeyError:
        logging.error("Unable to find all keys required for congress in "
                      "overcloudrc: OS_USERNAME, OS_PROJECT_NAME, "
                      "OS_PASSWORD, OS_AUTH_URL.  Please check overcloudrc "
                      "file: {}".format(overcloud_file))
        raise
    cmds = list()
    ds_cfg = '--config ' + ' --config '.join(ds_cfg)

    for driver in drivers:
        if driver == 'doctor':
            cmd = "{} \"{}\"".format(driver, driver)
        else:
            cmd = "{} \"{}\" {}".format(driver, driver, ds_cfg)
        if driver == 'nova':
            cmd += ' --config api_version="2.34"'
        logging.debug("Congress command created: {}".format(cmd))
        cmds.append(cmd)
    return cmds
