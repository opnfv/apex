##############################################################################
# Copyright (c) 2016 Michael Chapman (michapma@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


import yaml
import logging

REQ_DEPLOY_SETTINGS = ['sdn_controller',
                       'odl_version',
                       'sdn_l3',
                       'tacker',
                       'congress',
                       'dataplane',
                       'sfc',
                       'vpn']

OPT_DEPLOY_SETTINGS = ['performance']

VALID_ROLES = ['Controller', 'Compute', 'ObjectStorage']
VALID_PERF_OPTS = ['kernel', 'nova']
VALID_DATAPLANES = ['ovs', 'ovs_dpdk', 'fdio']


class DeploySettings:
    """
    This class parses a APEX deploy settings yaml file into an object

    Currently the parsed object is dumped into a bash global definition file
    for deploy.sh consumption. This object will later be used directly as
    deployment script move to python.
    """
    def __init__(self, filename):
        with open(filename, 'r') as settings_file:
            self.deploy_settings = yaml.load(settings_file)
            self._validate_settings()

    def _validate_settings(self):
        """
        Validates the deploy settings file provided

        DeploySettingsException will be raised if validation fails.
        """

        if 'deploy_options' not in self.deploy_settings:
            raise DeploySettingsException("No deploy options provided in"
                                          " deploy settings file")
        if 'global_params' not in self.deploy_settings:
            raise DeploySettingsException("No global options provided in"
                                          " deploy settings file")

        deploy_options = self.deploy_settings['deploy_options']
        if not isinstance(deploy_options, dict):
            raise DeploySettingsException("deploy_options should be a list")

        for setting, value in deploy_options.items():
            if setting not in REQ_DEPLOY_SETTINGS + OPT_DEPLOY_SETTINGS:
                raise DeploySettingsException("Invalid deploy_option {} "
                                              "specified".format(setting))
            if setting == 'dataplane':
                if value not in VALID_DATAPLANES:
                    planes = ' '.join(VALID_DATAPLANES)
                    raise DeploySettingsException(
                        "Invalid dataplane {} specified. Valid dataplanes:"
                        " {}".format(value, planes))

        for req_set in REQ_DEPLOY_SETTINGS:
            if req_set not in deploy_options:
                if req_set == 'dataplane':
                    self.deploy_settings['deploy_options'][req_set] = 'ovs'
                else:
                    self.deploy_settings['deploy_options'][req_set] = False

        if 'performance' in deploy_options:
            if not isinstance(deploy_options['performance'], dict):
                raise DeploySettingsException("Performance deploy_option"
                                              "must be a dictionary.")
            for role, role_perf_sets in deploy_options['performance'].items():
                if role not in VALID_ROLES:
                    raise DeploySettingsException("Performance role {}"
                                                  "is not valid, choose"
                                                  "from {}".format(
                                                      role,
                                                      " ".join(VALID_ROLES)
                                                  ))

                for key in role_perf_sets:
                    if key not in VALID_PERF_OPTS:
                        raise DeploySettingsException(
                                "Performance option {} is not valid, choose"
                                "from {}".format(key,
                                                 " ".join(VALID_PERF_OPTS)
                                                 ))

    def _dump_performance(self):
        """
        Creates performance settings string for bash consumption.

        Output will be in the form of a list that can be iterated over in
        bash, with each string being the direct input to the performance
        setting script in the form <role> <category> <key> <value> to
        facilitate modification of the correct image.
        """
        bash_str = 'performance_options=(\n'
        deploy_options = self.deploy_settings['deploy_options']
        for role, settings in deploy_options['performance'].items():
            for category, options in settings.items():
                for key, value in options.items():
                    bash_str += "\"{} {} {} {}\"\n".format(role,
                                                           category,
                                                           key,
                                                           value)
        bash_str += ')\n'
        bash_str += '\n'
        bash_str += 'performance_roles=(\n'
        for role in self.deploy_settings['deploy_options']['performance']:
            bash_str += role + '\n'
        bash_str += ')\n'
        bash_str += '\n'

        return bash_str

    def _dump_deploy_options_array(self):
        """
        Creates deploy settings array in bash syntax.
        """
        bash_str = ''
        for key, value in self.deploy_settings['deploy_options'].items():
            if not isinstance(value, bool):
                bash_str += "deploy_options_array[{}]=\"{}\"\n".format(key,
                                                                       value)
            else:
                bash_str += "deploy_options_array[{}]={}\n".format(key,
                                                                   value)
        return bash_str

    def dump_bash(self, path=None):
        """
        Prints settings for bash consumption.

        If optional path is provided, bash string will be written to the file
        instead of stdout.
        """
        bash_str = ''
        for key, value in self.deploy_settings['global_params'].items():
            bash_str += "{}={}\n".format(key, value)
        if 'performance' in self.deploy_settings['deploy_options']:
            bash_str += self._dump_performance()
        bash_str += self._dump_deploy_options_array()

        if path:
            with open(path, 'w') as file:
                file.write(bash_str)
        else:
            print(bash_str)


class DeploySettingsException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return self.value
