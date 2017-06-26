##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

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
