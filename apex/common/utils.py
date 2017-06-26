##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import json
import logging
import os
import pprint
import subprocess
import yaml


def str2bool(var):
    if isinstance(var, bool):
        return var
    else:
        return var.lower() in ("true", "yes")


def parse_yaml(yaml_file):
    with open(yaml_file) as f:
        parsed_dict = yaml.safe_load(f)
        return parsed_dict


def write_str(bash_str, path=None):
    if path:
        with open(path, 'w') as file:
            file.write(bash_str)
    else:
        print(bash_str)


def dump_yaml(data, file):
    """
    Dumps data to a file as yaml
    :param data: yaml to be written to file
    :param file: filename to write to
    :return:
    """
    with open(file, "w") as fh:
        yaml.safe_dump(data, fh, default_flow_style=False)


def dict_objects_to_str(dictionary):
        if isinstance(dictionary, list):
            tmp_list = []
            for element in dictionary:
                if isinstance(element, dict):
                    tmp_list.append(dict_objects_to_str(element))
                else:
                    tmp_list.append(str(element))
            return tmp_list
        elif not isinstance(dictionary, dict):
            if not isinstance(dictionary, bool):
                return str(dictionary)
            else:
                return dictionary
        return dict((k, dict_objects_to_str(v)) for
                    k, v in dictionary.items())


def run_ansible(ansible_vars, playbook, host='localhost', user='root',
                tmp_dir=None):
    """
    Executes ansible playbook and checks for errors
    :param ansible_vars: dictionary of variables to inject into ansible run
    :param playbook: playbook to execute
    :param tmp_dir: temp directory to store ansible command
    :return: None
    """
    logging.info("Executing ansible playbook: {}".format(playbook))
    inv_host = "{},".format(host)
    if host == 'localhost':
        conn_type = 'local'
    else:
        conn_type = 'smart'
    ansible_command = ['ansible-playbook', '--become', '-i', inv_host,
                       '-u', user, '-c', conn_type, playbook, '-vvv']

    if isinstance(ansible_vars, dict) and ansible_vars:
        logging.debug("Ansible variables to be set:\n{}".format(
            pprint.pformat(ansible_vars)))
        ansible_command.append('--extra-vars')
        ansible_command.append(json.dumps(ansible_vars))
        if tmp_dir:
            ansible_tmp = os.path.join(tmp_dir,
                                       os.path.basename(playbook) + '.rerun')
            # FIXME(trozet): extra vars are printed without single quotes
            # so a dev has to add them manually to the command to rerun
            # the playbook.  Need to test if we can just add the single quotes
            # to the json dumps to the ansible command and see if that works
            with open(ansible_tmp, 'w') as fh:
                fh.write("ANSIBLE_HOST_KEY_CHECKING=FALSE {}".format(
                    ' '.join(ansible_command)))
                fh.close()
    try:
        my_env = os.environ.copy()
        my_env['ANSIBLE_HOST_KEY_CHECKING'] = 'False'
        logging.info("Executing playbook...this may take some time")
        logging.debug(subprocess.check_output(ansible_command, env=my_env,
                      stderr=subprocess.STDOUT).decode('utf-8'))
    except subprocess.CalledProcessError as e:
        # FIXME(trozet): can we call decode on e.output?
        logging.error("Error executing ansible: {}".format(
            pprint.pformat(e.output.decode('utf-8'))))
        raise
