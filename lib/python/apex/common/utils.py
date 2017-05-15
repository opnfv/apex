##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import logging
import yaml
import yum

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


def check_package_dependencies(pkgs):
    yb = yum.YumBase()
    installed_pkgs = yb.rpmdb.returnPackages()
    installed = [x.name for x in installed_pkgs]
    for pkg in pkgs:
        if pkg in installed:
            logging.DEBUG('{} is already installed'.foramt(pkg))
        else:
            logging.DEBUG('Installing dependency package: {}'.format(pkg))
            pkg_def = {'name': pkg}
            yb.install(**pkg_def)
            yb.resolveDeps()
            yb.buildTransaction()
            yb.processTransaction()

