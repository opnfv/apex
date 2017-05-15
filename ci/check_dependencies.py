##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
import argparse
import re
import subprocess
import sys
import yum


DEPENDENCIES = {'build': ['https://www.rdoproject.org/repos/rdo-release.rpm',
                          'python34', 'python34-devel','python34-jinja2',
                          'python34-markupsafe', 'python2-virtualbmc',
                          'libguestfs-tools', 'bsdtar', 'libvirt',
                          'python2-oslo-config', 'python2-debtcollector',
                          'http://artifacts.opnfv.org/apex/dependencies'
                          '/python3-ipmi-0.3.0-1.noarch.rpm',
                          'Virtualization Host']
                }


def check_package_dependencies(pkgs):
    yb = yum.YumBase()
    installed_pkgs = yb.rpmdb.returnPackages()
    installed = [x.name for x in installed_pkgs]
    for pkg in pkgs:
        if pkg in installed:
            print('{} is already installed'.format(pkg))
        elif re.match('http', pkg) is not None:
            print('Installing dependency package: {}'.format(pkg))
            try:
                subprocess.check_output(['yum', '-y', 'install', pkg])
            except subprocess.CalledProcessError as e:
                if 'does not update' not in e.output:
                    print("Error installing package: {}".format(pkg))
                    raise e
        elif ' ' in pkg:
            print('Installing group package: {}'.format(pkg))
            subprocess.check_call(['yum', '-y', 'groupinstall', pkg])
        else:
            print('Installing dependency package: {}'.format(pkg))
            pkg_def = {'name': pkg}
            yb.install(**pkg_def)
            yb.resolveDeps()
            yb.buildTransaction()
            yb.processTransaction()
if __name__ == '__main__':
    dep_parser = argparse.ArgumentParser()
    dep_parser.add_argument('-d', '--dependency_type', required=True,
                            dest='dep_type', help="Dependency type",
                            choices=['build', 'deploy', 'clean'])
    args = dep_parser.parse_args(sys.argv[1:])
    check_package_dependencies(DEPENDENCIES[args.dep_type])
