##############################################################################
# Copyright (c) 2018 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# TODO(trozet): this will serve as the deployment class as we migrate logic out
# of deploy.py
import logging
import os
import pprint

from apex.common.exceptions import ApexDeployException
from apex.common import utils


class ApexDeployment:
    def __init__(self, deploy_settings, patch_file, ds_file):
        self.ds = deploy_settings
        # TODO(trozet): remove ds_file from args and have this class inherit
        # super deployment class init which does all the settings
        self.ds_file = ds_file
        self.ds_globals = self.ds['global_params']
        self.p_file = patch_file

    def determine_patches(self):
        patches = self.ds_globals['patches']
        if not os.path.isfile(self.p_file):
            new_file = os.path.join(os.path.dirname(self.ds_file),
                                    'common-patches.yaml')
            if os.path.isfile(new_file):
                logging.warning('Patch file {} not found, falling back to '
                                '{}'.format(self.p_file, new_file))
                self.p_file = new_file
            else:
                logging.error('Unable to find common patch file: '
                              '{}'.format(self.p_file))
                raise ApexDeployException(
                    'Specified common patch file not found: {}'.format(
                        self.p_file))
        logging.info('Loading patches from common patch file {}'.format(
            self.p_file))
        common_patches = utils.parse_yaml(self.p_file)
        logging.debug('Content from common patch file is: {}'.format(
            pprint.pformat(common_patches)))
        os_version = self.ds['deploy_options']['os_version']
        try:
            common_patches = common_patches['patches'][os_version]
        except KeyError:
            logging.error('Error parsing common patches file, wrong format.')
            raise ApexDeployException('Invalid format of common patch file')

        for ptype in ('undercloud', 'overcloud'):
            if ptype in common_patches:
                patches[ptype] = utils.unique(patches[ptype] +
                                              common_patches[ptype])
        return patches
