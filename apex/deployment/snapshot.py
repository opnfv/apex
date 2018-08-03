##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
import logging
import os

import apex.settings.deploy_settings as ds
import apex.common.constants as con

from apex.overcloud.node import overcloudNode
from apex.common import utils
from apex.common import exceptions as exc

SNAP_FILE = 'snapshot.properties'
CHECKSUM = 'OPNFV_SNAP_SHA512SUM'


class SnapshotDeployment:
    def __init__(self, deploy_settings, snap_cache_dir):
        self.id_rsa = None
        self.os_version = deploy_settings['os_version']
        self.ha_enabled = deploy_settings['global_params']['ha_enabled']
        self.snap_cache_dir = os.path.join(snap_cache_dir,
                                           "{}/{}".format(self.os_version,
                                                          self.ha_enabled))
        assert isinstance(deploy_settings, ds.DeploySettings)

        self.ha_ext = 'ha' if self.ha_enabled else 'noha'
        self.properties_url = "{}/apex/{}/{}".format(con.OPNFV_ARTIFACTS,
                                                     self.os_version,
                                                     self.ha_enabled)
        self.pull_snapshot(self.properties_url, self.snap_cache_dir)
        self.deploy_snapshot()

    def pull_snapshot(self, url_path, snap_cache_dir):
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
                "Unable to fetch upstream properties from {}".format(
                full_url)
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
            utils.fetch_upstream_and_unpack(dest=snap_cache_dir,
                                            url=url_path,
                                            targets=upstream_props[
                                                'OPNFV_SNAP_URL'])

    def create_networks(self):
        pass

    def parse_and_create_nodes(self):
        """
        Parse snapshot node.yaml config file and create overcloud nodes
        :return:
        """
        pass

    def is_openstack_up(self):
        pass

    def is_odl_up(self):
        pass

    def deploy_snapshot(self):
        # bring up networks
        self.create_networks()
        # check overcloudrc exists, id_rsa

        # create nodes

        # validate deployment

        self.is_openstack_up()
        self.is_odl_up()
