##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import apex.settings.deploy_settings as ds
import apex.common.constants as con

from apex.overcloud.node import overcloudNode


class SnapshotDeployment:
    def __init__(self, deploy_settings, snap_cache_dir):
        self.id_rsa = None
        self.snap_cache_dir = snap_cache_dir
        assert isinstance(deploy_settings, ds.DeploySettings)
        self.os_version = deploy_settings['os_version']
        self.ha_enabled = deploy_settings['global_params']['ha_enabled']
        self.ha_ext = 'ha' if self.ha_enabled else 'noha'
        self.properties_url = "{}/apex/{}/{}".format(con.OPNFV_ARTIFACTS,
                                                     self.os_version,
                                                     self.ha_enabled)
        self.pull_snapshot(self.properties_url, self.snap_cache_dir)
        self.parse_and_create_nodes()

    def pull_snapshot(self, url_path, snap_cache):
        """
        Compare opnfv properties file and download and unpack snapshot if
        necessary
        :param url_path:
        :param snap_cache:
        :return:
        """
        pass

    def parse_and_create_nodes(self):
        """
        Parse snapshot node.yaml config file and create overcloud nodes
        :return:
        """

    def is_openstack_up(self):
        pass

    def is_odl_up(self):
        pass


