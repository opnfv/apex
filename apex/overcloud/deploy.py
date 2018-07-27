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
import platform
import shutil
import uuid
import struct
import time
import apex.builders.overcloud_builder as oc_builder
import apex.builders.common_builder as c_builder

from apex.common import constants as con
from apex.common.exceptions import ApexDeployException
from apex.common import parsers
from apex.common import utils
from apex.virtual import utils as virt_utils
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
            'dvr': 'neutron-opendaylight-fdio-dvr.yaml',
            'default': 'neutron-opendaylight-honeycomb.yaml'
        },
        'l2gw': 'neutron-l2gw-opendaylight.yaml',
        'sriov': 'neutron-opendaylight-sriov.yaml',
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

LOSETUP_SERVICE = """[Unit]
Description=Setup loop devices
Before=network.target

[Service]
Type=oneshot
ExecStart=/sbin/losetup /dev/loop3 /srv/data.img
ExecStop=/sbin/losetup -d /dev/loop3
TimeoutSec=60
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
"""


def build_sdn_env_list(ds, sdn_map, env_list=None):
    """
    Builds a list of SDN environment files to be used in the deploy cmd.

    This function recursively searches an sdn_map.  First the sdn controller is
    matched and then the function looks for enabled features for that
    controller to determine which environment files should be used.  By
    default the feature will be checked if set to true in deploy settings to be
    added to the list.  If a feature does not have a boolean value, then the
    key and value pair to compare with are checked as a tuple (k,v).

    :param ds: deploy settings
    :param sdn_map: SDN map to recursively search
    :param env_list: recursive var to hold previously found env_list
    :return: A list of env files
    """
    if env_list is None:
        env_list = list()
    for k, v in sdn_map.items():
        if ds['sdn_controller'] == k or (k in ds and ds[k]):
            if isinstance(v, dict):
                # Append default SDN env file first
                # The assumption is that feature-enabled SDN env files
                # override and do not conflict with previously set default
                # settings
                if ds['sdn_controller'] == k and 'default' in v:
                    env_list.append(os.path.join(con.THT_ENV_DIR,
                                                 v['default']))
                env_list.extend(build_sdn_env_list(ds, v))
            # check if the value is not a boolean
            elif isinstance(v, tuple):
                    if ds[k] == v[0]:
                        env_list.append(os.path.join(con.THT_ENV_DIR, v[1]))
            else:
                env_list.append(os.path.join(con.THT_ENV_DIR, v))
    if len(env_list) == 0:
        try:
            env_list.append(os.path.join(
                con.THT_ENV_DIR, sdn_map['default']))
        except KeyError:
            logging.warning("Unable to find default file for SDN")

    return env_list


def get_docker_sdn_file(ds_opts):
    """
    Returns docker env file for detected SDN
    :param ds_opts: deploy options
    :return: docker THT env file for an SDN
    """
    # FIXME(trozet): We assume right now there is only one docker SDN file
    docker_services = con.VALID_DOCKER_SERVICES
    tht_dir = con.THT_DOCKER_ENV_DIR[ds_opts['os_version']]
    sdn_env_list = build_sdn_env_list(ds_opts, SDN_FILE_MAP)
    for sdn_file in sdn_env_list:
        sdn_base = os.path.basename(sdn_file)
        if sdn_base in docker_services:
            if docker_services[sdn_base] is not None:
                return os.path.join(tht_dir,
                                    docker_services[sdn_base])
            else:
                return os.path.join(tht_dir, sdn_base)


def create_deploy_cmd(ds, ns, inv, tmp_dir,
                      virtual, env_file='opnfv-environment.yaml',
                      net_data=False):

    logging.info("Creating deployment command")
    deploy_options = ['network-environment.yaml']

    ds_opts = ds['deploy_options']

    if ds_opts['containers']:
        deploy_options.append(os.path.join(con.THT_ENV_DIR,
                                           'docker.yaml'))

    if ds['global_params']['ha_enabled']:
        if ds_opts['containers']:
            deploy_options.append(os.path.join(con.THT_ENV_DIR,
                                               'docker-ha.yaml'))
        else:
            deploy_options.append(os.path.join(con.THT_ENV_DIR,
                                               'puppet-pacemaker.yaml'))

    if env_file:
        deploy_options.append(env_file)

    if ds_opts['containers']:
        deploy_options.append('docker-images.yaml')
        sdn_docker_file = get_docker_sdn_file(ds_opts)
        if sdn_docker_file:
            deploy_options.append(sdn_docker_file)
            deploy_options.append('sdn-images.yaml')
    else:
        deploy_options += build_sdn_env_list(ds_opts, SDN_FILE_MAP)

    for k, v in OTHER_FILE_MAP.items():
        if k in ds_opts and ds_opts[k]:
            if ds_opts['containers']:
                deploy_options.append(os.path.join(con.THT_DOCKER_ENV_DIR,
                                                   "{}.yaml".format(k)))
            else:
                deploy_options.append(os.path.join(con.THT_ENV_DIR, v))

    if ds_opts['ceph'] and 'csit' not in env_file:
        prep_storage_env(ds, ns, virtual, tmp_dir)
        deploy_options.append(os.path.join(con.THT_ENV_DIR,
                                           'storage-environment.yaml'))
    if ds_opts['sriov']:
        prep_sriov_env(ds, tmp_dir)

    # Check for 'k8s' here intentionally, as we may support other values
    # such as openstack/openshift for 'vim' option.
    if ds_opts['vim'] == 'k8s':
        deploy_options.append('kubernetes-environment.yaml')

    if virtual:
        deploy_options.append('virtual-environment.yaml')
    else:
        deploy_options.append('baremetal-environment.yaml')

    num_control, num_compute = inv.get_node_counts()
    if num_control == 0 or num_compute == 0:
        logging.error("Detected 0 control or compute nodes.  Control nodes: "
                      "{}, compute nodes{}".format(num_control, num_compute))
        raise ApexDeployException("Invalid number of control or computes")
    elif num_control > 1 and not ds['global_params']['ha_enabled']:
        num_control = 1
    if platform.machine() == 'aarch64':
        # aarch64 deploys were not completing in the default 90 mins.
        # Not sure if this is related to the hardware the OOO support
        # was developed on or the virtualization support in CentOS
        # Either way it will probably get better over time  as the aarch
        # support matures in CentOS and deploy time should be tested in
        # the future so this multiplier can be removed.
        con.DEPLOY_TIMEOUT *= 2
    cmd = "openstack overcloud deploy --templates --timeout {} " \
          .format(con.DEPLOY_TIMEOUT)
    # build cmd env args
    for option in deploy_options:
        cmd += " -e {}".format(option)
    cmd += " --ntp-server {}".format(ns['ntp'][0])
    cmd += " --control-scale {}".format(num_control)
    cmd += " --compute-scale {}".format(num_compute)
    cmd += ' --control-flavor control --compute-flavor compute'
    if net_data:
        cmd += ' --networks-file network_data.yaml'
    libvirt_type = 'kvm'
    if virtual:
        with open('/sys/module/kvm_intel/parameters/nested') as f:
            nested_kvm = f.read().strip()
            if nested_kvm != 'Y':
                libvirt_type = 'qemu'
    cmd += ' --libvirt-type {}'.format(libvirt_type)
    logging.info("Deploy command set: {}".format(cmd))

    with open(os.path.join(tmp_dir, 'deploy_command'), 'w') as fh:
        fh.write(cmd)
    return cmd


def prep_image(ds, ns, img, tmp_dir, root_pw=None, docker_tag=None,
               patches=None):
    """
    Locates sdn image and preps for deployment.
    :param ds: deploy settings
    :param ns: network settings
    :param img: sdn image
    :param tmp_dir: dir to store modified sdn image
    :param root_pw: password to configure for overcloud image
    :param docker_tag: Docker image tag for RDO version (default None)
    :param patches: List of patches to apply to overcloud image
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
    patched_containers = set()
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

    if ns.get('http_proxy', ''):
        virt_cmds.append({
            con.VIRT_RUN_CMD:
                "echo 'http_proxy={}' >> /etc/environment".format(
                    ns['http_proxy'])})

    if ns.get('https_proxy', ''):
        virt_cmds.append({
            con.VIRT_RUN_CMD:
                "echo 'https_proxy={}' >> /etc/environment".format(
                    ns['https_proxy'])})

    tmp_oc_image = os.path.join(tmp_dir, 'overcloud-full.qcow2')
    shutil.copyfile(img, tmp_oc_image)
    logging.debug("Temporary overcloud image stored as: {}".format(
        tmp_oc_image))

    if ds_opts['vpn']:
        oc_builder.inject_quagga(tmp_oc_image,tmp_dir)
        virt_cmds.append({con.VIRT_RUN_CMD: "chmod +x /etc/rc.d/rc.local"})
        virt_cmds.append({
            con.VIRT_RUN_CMD:
                "echo 'sudo /opt/quagga/etc/init.d/zrpcd start' > "
                "/opt/quagga/etc/init.d/zrpcd_start.sh"})
        virt_cmds.append({
            con.VIRT_RUN_CMD: "chmod +x /opt/quagga/etc/init.d/"
                              "zrpcd_start.sh"})
        virt_cmds.append({
            con.VIRT_RUN_CMD: "sed -i '$a /opt/quagga/etc/"
                              "init.d/zrpcd_start.sh' /etc/rc.local "})
        virt_cmds.append({
            con.VIRT_RUN_CMD: "sed -i '$a /opt/quagga/etc/"
                              "init.d/zrpcd_start.sh' /etc/rc.d/rc.local"})
        logging.info("ZRPCD process started")

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
        if sdn is False:
            virt_cmds.extend([
                {con.VIRT_RUN_CMD: "yum remove -y vpp-lib"},
                {con.VIRT_RUN_CMD: "yum install -y "
                                   "/root/nosdn_vpp_rpms/*.rpm"}
            ])

    if sdn == 'opendaylight':
        undercloud_admin_ip = ns['networks'][con.ADMIN_NETWORK][
            'installer_vm']['ip']
        oc_builder.inject_opendaylight(
            odl_version=ds_opts['odl_version'],
            image=tmp_oc_image,
            tmp_dir=tmp_dir,
            uc_ip=undercloud_admin_ip,
            os_version=ds_opts['os_version'],
            docker_tag=docker_tag,
        )
        if docker_tag:
            patched_containers = patched_containers.union({'opendaylight'})

    if patches:
        if ds_opts['os_version'] == 'master':
            branch = ds_opts['os_version']
        else:
            branch = "stable/{}".format(ds_opts['os_version'])
        logging.info('Adding patches to overcloud')
        patched_containers = patched_containers.union(
            c_builder.add_upstream_patches(patches,
                                           tmp_oc_image, tmp_dir,
                                           branch,
                                           uc_ip=undercloud_admin_ip,
                                           docker_tag=docker_tag))
    # if containers with ceph, and no ceph device we need to use a
    # persistent loop device for Ceph OSDs
    if docker_tag and ds_opts['ceph_device'] == '/dev/loop3':
        tmp_losetup = os.path.join(tmp_dir, 'losetup.service')
        with open(tmp_losetup, 'w') as fh:
            fh.write(LOSETUP_SERVICE)
        virt_cmds.extend([
            {con.VIRT_UPLOAD: "{}:/usr/lib/systemd/system/".format(tmp_losetup)
             },
            {con.VIRT_RUN_CMD: 'truncate /srv/data.img --size 10G'},
            {con.VIRT_RUN_CMD: 'systemctl daemon-reload'},
            {con.VIRT_RUN_CMD: 'systemctl enable losetup.service'},
        ])
    # TODO(trozet) remove this after LP#173474 is fixed
    dhcp_unit = '/usr/lib/systemd/system/dhcp-interface@.service'
    virt_cmds.append(
        {con.VIRT_RUN_CMD: "crudini --del {} Unit "
                           "ConditionPathExists".format(dhcp_unit)})
    virt_utils.virt_customize(virt_cmds, tmp_oc_image)
    logging.info("Overcloud image customization complete")
    return patched_containers


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
    return private_key.decode('utf-8'), public_key.decode('utf-8')


def prep_env(ds, ns, inv, opnfv_env, net_env, tmp_dir):
    """
    Creates modified opnfv/network environments for deployment
    :param ds: deploy settings
    :param ns: network settings
    :param inv: node inventory
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
    tenant_nic = dict()
    tenant_nic['Controller'] = tenant_nic_map['controller']['members'][0]
    tenant_nic['NovaCompute'] = tenant_nic_map['compute']['members'][0]
    external_nic_map = ns['networks']['external'][0]['nic_mapping']
    external_nic = dict()
    external_nic['NovaCompute'] = external_nic_map['compute']['members'][0]

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

    tenant_settings = ns['networks']['tenant']
    tenant_vlan_enabled = 'tenant' in ns.enabled_network_list and \
        ns['networks']['tenant'].get('segmentation_type') == 'vlan'

    # Modify OPNFV environment
    # TODO: Change to build a dict and outputting yaml rather than parsing
    for line in fileinput.input(tmp_opnfv_env, inplace=True):
        line = line.strip('\n')
        output_line = line
        if 'CloudDomain' in line:
            output_line = "  CloudDomain: {}".format(ns['domain_name'])
        elif 'replace_private_key' in line:
            output_line = "    private_key: |\n"
            key_out = ''
            for line in private_key.splitlines():
                key_out += "      {}\n".format(line)
            output_line += key_out
        elif 'replace_public_key' in line:
            output_line = "    public_key: '{}'".format(public_key)
        elif ((perf and perf_kern_comp) or ds_opts.get('rt_kvm')) and \
                'resource_registry' in line:
            output_line = "resource_registry:\n" \
                          "  OS::TripleO::NodeUserData: first-boot.yaml"
        elif 'ComputeExtraConfigPre' in line and \
                ds_opts['dataplane'] == 'ovs_dpdk':
            output_line = '  OS::TripleO::ComputeExtraConfigPre: ' \
                          './ovs-dpdk-preconfig.yaml'
        elif 'NeutronNetworkVLANRanges' in line:
            vlan_setting = ''
            if tenant_vlan_enabled:
                if ns['networks']['tenant']['overlay_id_range']:
                    vlan_setting = ns['networks']['tenant']['overlay_id_range']
                    if 'datacentre' not in vlan_setting:
                        vlan_setting += ',datacentre:1:1000'
            # SRIOV networks are VLAN based provider networks. In order to
            # simplify the deployment, nfv_sriov will be the default physnet.
            # VLANs are not needed in advance, and the user will have to create
            # the network specifying the segmentation-id.
            if ds_opts['sriov']:
                if vlan_setting:
                    vlan_setting += ",nfv_sriov"
                else:
                    vlan_setting = "datacentre:1:1000,nfv_sriov"
            if vlan_setting:
                output_line = "  NeutronNetworkVLANRanges: " + vlan_setting
        elif 'NeutronBridgeMappings' in line and tenant_vlan_enabled:
            if tenant_settings['overlay_id_range']:
                physnets = tenant_settings['overlay_id_range'].split(',')
                output_line = "  NeutronBridgeMappings: "
                for physnet in physnets:
                    physnet_name = physnet.split(':')[0]
                    if physnet_name != 'datacentre':
                        output_line += "{}:br-vlan,".format(physnet_name)
                output_line += "datacentre:br-ex"
        elif 'OpenDaylightProviderMappings' in line and tenant_vlan_enabled \
                and ds_opts['sdn_controller'] == 'opendaylight':
            if tenant_settings['overlay_id_range']:
                physnets = tenant_settings['overlay_id_range'].split(',')
                output_line = "  OpenDaylightProviderMappings: "
                for physnet in physnets:
                    physnet_name = physnet.split(':')[0]
                    if physnet_name != 'datacentre':
                        output_line += "{}:br-vlan,".format(physnet_name)
                output_line += "datacentre:br-ex"
        elif 'NeutronNetworkType' in line and tenant_vlan_enabled:
            output_line = "  NeutronNetworkType: vlan\n" \
                          "  NeutronTunnelTypes: ''"

        if ds_opts['sdn_controller'] == 'opendaylight' and \
                'odl_vpp_routing_node' in ds_opts:
            if 'opendaylight::vpp_routing_node' in line:
                output_line = ("    opendaylight::vpp_routing_node: {}.{}"
                               .format(ds_opts['odl_vpp_routing_node'],
                                       ns['domain_name']))
        elif not ds_opts['sdn_controller'] and ds_opts['dataplane'] == 'fdio':
            if 'NeutronVPPAgentPhysnets' in line:
                # VPP interface tap0 will be used for external network
                # connectivity.
                output_line = ("  NeutronVPPAgentPhysnets: "
                               "'datacentre:{},external:tap0'"
                               .format(tenant_nic['Controller']))
        elif ds_opts['sdn_controller'] == 'opendaylight' and ds_opts.get(
                'dvr') is True:
            if 'OS::TripleO::Services::NeutronDhcpAgent' in line:
                output_line = ''
            elif 'NeutronDhcpAgentsPerNetwork' in line:
                num_control, num_compute = inv.get_node_counts()
                output_line = ("  NeutronDhcpAgentsPerNetwork: {}"
                               .format(num_compute))
            elif 'ComputeServices' in line:
                output_line = ("  ComputeServices:\n"
                               "    - OS::TripleO::Services::NeutronDhcpAgent")

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
                    if ds_opts['sdn_controller'] == 'opendaylight' and \
                            ds_opts['dataplane'] == 'fdio':
                        if role == 'NovaCompute':
                            perf_line += ("\n    "
                                          "tripleo::profile::base::neutron::"
                                          "agents::honeycomb::"
                                          "interface_role_mapping:"
                                          " ['{}:tenant-interface',"
                                          "'{}:public-interface']"
                                          .format(tenant_nic[role],
                                                  external_nic[role]))
                        else:
                            perf_line += ("\n    "
                                          "tripleo::profile::base::neutron::"
                                          "agents::honeycomb::"
                                          "interface_role_mapping:"
                                          " ['{}:tenant-interface']"
                                          .format(tenant_nic[role]))
                    if perf_line:
                        output_line = ("  {}:{}".format(cfg, perf_line))

            if ds_opts['dataplane'] == 'ovs_dpdk' and perf_ovs_comp:
                for k, v in OVS_PERF_MAP.items():
                    if k in line and v in perf_ovs_comp:
                        output_line = "  {}: '{}'".format(k, perf_ovs_comp[v])

            # kernel args
            # (FIXME) use compute's kernel settings for all nodes for now.
            if perf_kern_comp:
                if 'NovaSchedulerDefaultFilters' in line:
                    output_line = \
                        "  NovaSchedulerDefaultFilters: 'RamFilter," \
                        "ComputeFilter,AvailabilityZoneFilter," \
                        "ComputeCapabilitiesFilter," \
                        "ImagePropertiesFilter,NUMATopologyFilter'"
                elif 'ComputeKernelArgs' in line:
                    kernel_args = ''
                    for k, v in perf_kern_comp.items():
                        kernel_args += "{}={} ".format(k, v)
                    if kernel_args:
                        output_line = "  ComputeKernelArgs: '{}'".\
                            format(kernel_args)

        print(output_line)

    logging.info("opnfv-environment file written to {}".format(tmp_opnfv_env))


def generate_ceph_key():
    key = os.urandom(16)
    header = struct.pack('<hiih', 1, int(time.time()), 0, len(key))
    return base64.b64encode(header + key)


def prep_storage_env(ds, ns, virtual, tmp_dir):
    """
    Creates storage environment file for deployment.  Source file is copied by
    undercloud playbook to host.
    :param ds:
    :param ns:
    :param virtual:
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
        elif 'CephClientKey' in line:
            print("  CephClientKey: {}".format(generate_ceph_key().decode(
                'utf-8')))
        else:
            print(line)

    if ds_opts['containers']:
        undercloud_admin_ip = ns['networks'][con.ADMIN_NETWORK][
            'installer_vm']['ip']
        ceph_version = con.CEPH_VERSION_MAP[ds_opts['os_version']]
        docker_image = "{}:8787/ceph/daemon:tag-build-master-" \
                       "{}-centos-7".format(undercloud_admin_ip,
                                            ceph_version)
        ceph_params = {
            'DockerCephDaemonImage': docker_image,
        }

        # max pgs allowed are calculated as num_mons * 200. Therefore we
        # set number of pgs and pools so that the total will be less:
        # num_pgs * num_pools * num_osds
        ceph_params['CephPoolDefaultSize'] = 2
        ceph_params['CephPoolDefaultPgNum'] = 32
        if virtual:
            ceph_params['CephAnsibleExtraConfig'] = {
                'centos_package_dependencies': [],
                'ceph_osd_docker_memory_limit': '1g',
                'ceph_mds_docker_memory_limit': '1g',
            }
        ceph_device = ds_opts['ceph_device']
        ceph_params['CephAnsibleDisksConfig'] = {
            'devices': [ceph_device],
            'journal_size': 512,
            'osd_scenario': 'collocated'
        }
        utils.edit_tht_env(storage_file, 'parameter_defaults', ceph_params)
    # TODO(trozet): remove following block as we only support containers now
    elif 'ceph_device' in ds_opts and ds_opts['ceph_device']:
        with open(storage_file, 'a') as fh:
            fh.write('  ExtraConfig:\n')
            fh.write("    ceph::profile::params::osds:{{{}:{{}}}}\n".format(
                ds_opts['ceph_device']
            ))


def prep_sriov_env(ds, tmp_dir):
    """
    Creates SRIOV environment file for deployment. Source file is copied by
    undercloud playbook to host.
    :param ds:
    :param tmp_dir:
    :return:
    """
    ds_opts = ds['deploy_options']
    sriov_iface = ds_opts['sriov']
    sriov_file = os.path.join(tmp_dir, 'neutron-opendaylight-sriov.yaml')
    if not os.path.isfile(sriov_file):
        logging.error("sriov-environment file is not in tmp directory: {}. "
                      "Check if file was copied from "
                      "undercloud".format(tmp_dir))
        raise ApexDeployException("sriov-environment file not copied from "
                                  "undercloud")
    # TODO(rnoriega): Instead of line editing, refactor this code to load
    # yaml file into a dict, edit it and write the file back.
    for line in fileinput.input(sriov_file, inplace=True):
        line = line.strip('\n')
        if 'NovaSchedulerDefaultFilters' in line:
            print("  {}".format(line[3:]))
        elif 'NovaSchedulerAvailableFilters' in line:
            print("  {}".format(line[3:]))
        elif 'NeutronPhysicalDevMappings' in line:
            print("  NeutronPhysicalDevMappings: \"nfv_sriov:{}\""
                  .format(sriov_iface))
        elif 'NeutronSriovNumVFs' in line:
            print("  NeutronSriovNumVFs: \"{}:8\"".format(sriov_iface))
        elif 'NovaPCIPassthrough' in line:
            print("  NovaPCIPassthrough:")
        elif 'devname' in line:
            print("    - devname: \"{}\"".format(sriov_iface))
        elif 'physical_network' in line:
            print("      physical_network: \"nfv_sriov\"")
        else:
            print(line)


def external_network_cmds(ns, ds):
    """
    Generates external network openstack commands
    :param ns: network settings
    :param ds: deploy settings
    :return: list of commands to configure external network
    """
    ds_opts = ds['deploy_options']
    external_physnet = 'datacentre'
    if ds_opts['dataplane'] == 'fdio' and \
       ds_opts['sdn_controller'] != 'opendaylight':
        external_physnet = 'external'
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
                "--provider-physical-network {}"
                .format(ext_type, external_physnet))
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
