##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
import fnmatch
import libvirt
import logging
import os
import pprint

import apex.settings.deploy_settings as ds
import apex.common.constants as con

from apex.overcloud.node import OvercloudNode
from apex.common import utils
from apex.common import exceptions as exc

SNAP_FILE = 'snapshot.properties'
CHECKSUM = 'OPNFV_SNAP_SHA512SUM'


class SnapshotDeployment:
    def __init__(self, deploy_settings, snap_cache_dir, fetch=True):
        self.id_rsa = None
        self.fetch = fetch
        ds_opts = deploy_settings['deploy_options']
        self.os_version = ds_opts['os_version']
        self.ha_enabled = deploy_settings['global_params']['ha_enabled']
        self.ha_ext = 'ha' if self.ha_enabled else 'noha'
        self.snap_cache_dir = os.path.join(snap_cache_dir,
                                           "{}/{}".format(self.os_version,
                                                          self.ha_ext))
        assert isinstance(deploy_settings, ds.DeploySettings)
        self.networks = []
        self.oc_nodes = []
        self.properties_url = "{}/apex/{}/{}".format(con.OPNFV_ARTIFACTS,
                                                     self.os_version,
                                                     self.ha_ext)
        self.conn = libvirt.open('qemu:///system')
        if not self.conn:
            raise exc.SnapshotDeployException(
                'Unable to open libvirt connection')
        if self.fetch:
            self.pull_snapshot(self.properties_url, self.snap_cache_dir)
        else:
            logging.info('No fetch enabled. Will not attempt to pull latest '
                         'snapshot')
        self.deploy_snapshot()

    @ staticmethod
    def pull_snapshot(url_path, snap_cache_dir):
        """
        Compare opnfv properties file and download and unpack snapshot if
        necessary
        :param url_path: path of latest snap info
        :param snap_cache_dir: local directory for snap cache
        :return:
        """
        full_url = os.path.join(url_path, SNAP_FILE)
        upstream_props = utils.fetch_properties(full_url)
        if upstream_props is None:
            raise exc.SnapshotDeployException(
                "Unable to fetch upstream properties from {}".format(full_url)
            )
        logging.debug("Upstream properties are: {}".format(upstream_props))
        local_prop_file = os.path.join(snap_cache_dir, SNAP_FILE)
        local_props = utils.fetch_properties(local_prop_file)
        if local_props is None:
            logging.info("No locally cached properties found, will pull "
                         "latest")
            pull_snap = True
        else:
            local_sha = local_props.get(CHECKSUM, None)
            try:
                upstream_sha = upstream_props[CHECKSUM]
            except KeyError:
                logging.error('Unable to find {} for upstream properties: '
                              '{}'.format(CHECKSUM, upstream_props))
                raise exc.SnapshotDeployException('Unable to find upstream '
                                                  'properties checksum value')
            pull_snap = local_sha != upstream_sha
            logging.debug('Local sha: {}, Upstream sha: {}'.format(local_sha,
                                                                   upstream_sha
                                                                   ))
        if pull_snap:
            logging.info('SHA mismatch, will download latest snapshot')
            full_snap_url = upstream_props['OPNFV_SNAP_URL']
            snap_file = os.path.basename(full_snap_url)
            snap_url = full_snap_url.replace(snap_file, '')
            if not snap_url.startswith('http://'):
                snap_url = 'http://' + snap_url
            utils.fetch_upstream_and_unpack(dest=snap_cache_dir,
                                            url=snap_url,
                                            targets=[SNAP_FILE, snap_file]
                                            )
        else:
            logging.info('SHA match, artifacts in cache are already latest. '
                         'Will not download.')

    def create_networks(self):
        logging.info("Detecting snapshot networks")
        xmls = fnmatch.filter(os.listdir(self.snap_cache_dir), '*.xml')
        net_xmls = list()
        for xml in xmls:
            if xml.startswith('baremetal'):
                continue
            net_xmls.append(os.path.join(self.snap_cache_dir, xml))
        if not net_xmls:
            raise exc.SnapshotDeployException(
                'No network XML files detected in snap cache, '
                'please check local snap cache contents')
        logging.info('Snapshot networks found: {}'.format(net_xmls))
        for xml in net_xmls:
            logging.debug('Creating network from {}'.format(xml))
            with open(xml, 'r') as fh:
                net_xml = fh.read()
            net = self.conn.networkCreateXML(net_xml)
            self.networks.append(net)
            logging.info('Network started: {}'.format(net.name()))

    def parse_and_create_nodes(self):
        """
        Parse snapshot node.yaml config file and create overcloud nodes
        :return:
        """
        node_file = os.path.join(self.snap_cache_dir, 'node.yaml')
        if not os.path.isfile(node_file):
            raise exc.SnapshotDeployException('Missing node definitions from '
                                              ''.format(node_file))
        node_data = utils.parse_yaml(node_file)
        if 'servers' not in node_data:
            raise exc.SnapshotDeployException('Invalid node.yaml format')
        for node, data in node_data['servers'].items():
            logging.info('Creating node: {}'.format(node))
            logging.debug('Node data is:\n{}'.format(pprint.pformat(data)))
            node_xml = os.path.join(self.snap_cache_dir,
                                    '{}.xml'.format(data['vNode-name']))
            node_qcow = os.path.join(self.snap_cache_dir,
                                     '{}.qcow2'.format(data['vNode-name']))
            self.oc_nodes.append(
                OvercloudNode(ip=data['address'],
                              ovs_ctrlrs=data['ovs-controller'],
                              ovs_mgrs=data['ovs-managers'],
                              role=data['type'],
                              name=node,
                              node_xml=node_xml,
                              disk_img=node_qcow)
            )
            logging.info('Node Created')
        logging.info('Starting nodes')
        for node in self.oc_nodes:
            node.start()

    def is_openstack_up(self):
        pass

    def is_odl_up(self):
        pass

    def deploy_snapshot(self):
        # bring up networks
        self.create_networks()
        # check overcloudrc exists, id_rsa

        # create nodes
        self.parse_and_create_nodes()
        # validate deployment

        self.is_openstack_up()
        self.is_odl_up()
