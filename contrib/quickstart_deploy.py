#/usr/bin/env python
##############################################################################
# Copyright (c) Michael Chapman (michapma@redhat.com)
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import logging
import os
import sys

quickstart_requirements = [ '-r', 'contrib/apex-requirements.txt',
                            '-r', 'requirements.txt',
                            '-r', 'quickstart-extras-requirements.txt ']

base_dir = '/var/opt/opnfv/apex'

def deploy(args):
    """
    Deploy Apex using tripleo-quickstart.
    """

    # TODO package quickstart so we don't need to clone - needed for offline
    base_dir = args.base_directory

    # Clone tripleo-quickstart if it's not already found in cwd
    if 'tripleo-quickstart' not in os.listdir(base_dir):
        command = ['git', 'clone', args.quickstart_repo,
               basedir('tripleo-quickstart')]
        subprocess.call(command)

        command = ['git', 'checkout', args.quickstart_ref]
        subprocess.Popen(command, cwd=base_dir)

    #bash quickstart.sh -v $PLAYBOOK $REQUIREMENTS $NETWORK $DEPLOY $INVENTORY $VIRTUAL $CONFIG --tags all --teardown all -n -X     $VIRTHOST

    command = [basedir('tripleo-quickstart/quickstart.sh')]

    if args.debug:
        command.append('-v')

    # this doesn't need the basedir since it's copied within the virtual env
    command.append(args.quickstart_playbook)

    for r in quickstart_requirements:
        command.append(r)

    command.append('-e')
    command.append("apex_network_settings_file="+basedir(args.network_settings))
    command.append('-e')
    command.append("apex_deploy_settings_file="+basedir(args.deploy_settings))

    if args.inventory_settings:
        command.append('-e')
        command.append(basedir(args.inventory_settings))

    command.append('-e')
    command.append('apex_virtual='+args.virtual)

    command.append('-c')
    command.append(basedir(args.quickstart_defaults))

    command.append('--tags')
    command.append('all')

    command.append('--teardown')
    command.append('all')

    command.append('-n')
    command.append('-X')

    # this might need a shell
    # runs tripleo-quickstart's quickstart.sh
    logging.debug("Quickstart command: {}".format(" ".join(command)))
    subprocess.Popen(command, cwd=args.base_directory, shell=True)

def clean(args):
    """
    Clean Apex install that was deployed using tripleo-quickstart.

    """
    #TODO this can use the teardown tags and possibly a custom playbook


def get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('--debug', action='store_true', default=False,
                        help="Turn on debug messages")
    parser.add_argument('-l', '--log-file', default='/var/log/apex/apex.log',
                        dest='log_file', help="Log file to log to")
    subparsers = parser.add_subparsers()
    # deploy
    deploy = subparsers.add_parser('deploy', help='Deploy Apex')

    deploy.add_argument('virthost'
                        help='Target machine on which to install Apex')

    deploy.add_argument('-b', '--base-directory',
                              default=os.getcwd(),
                              dest='base_directory',
                              help='Apex Directory under which to find config')

    deploy.add_argument('-n', '--network-settings-file',
                              default='network-settings.yaml',
                              dest='net_settings',
                              help='Path to network settings file')

    deploy.add_argument('-s', '--deploy-settings-file',
                              default="os-nosdn-nofeature-noha.yaml",
                              dest='deploy_settings',
                              help='Path to deploy settings (scenario) file')

    deploy.add_argument('-i', '--inventory-settings-file',
                              dest='inventory_settings',
                              help='Path to inventory settings file')

    deploy.add_argument('-p', '--playbook',
                              default="apex-overcloud.yaml",
                              dest='quickstart_playbook',
                              help='Ansible playbook to use for quickstart')

    deploy.add_argument('-c', '--quickstart-defaults',
                              default="contrib/quickstart_defaults.yaml",
                              dest='quickstart_defaults',
                              help='Path to quickstart defaults file')

    deploy.add_argument('-v', '--virtual',
                              default=False,
                              action='store_true',
                              help='Deploy overcloud using virtual machines')

    # TODO these should go away once we have a build process for oooq
    deploy.add_argument('-q', '--quickstart-ref',
                              default="master",
                              dest='quickstart_ref',
                              help='Git ref to use for tripleo-quickstart')

    deploy.add_argument('-r', '--quickstart-repo',
                              default="https://github.com/openstack/tripleo-quickstart",
                              dest='quickstart_repo',
                              help='Git repo to use for tripleo-quickstart')

    deploy.set_defaults(func=deploy)

    return parser

def basedir(path, base=base_dir):
    if path[0] != '/':
        return base + '/' + path
    else:
        return path

def main():
    parser = get_parser()
    args = parser.parse_args(sys.argv[1:])
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        apex_log_filename = args.log_file
        os.makedirs(os.path.dirname(apex_log_filename), exist_ok=True)
        logging.basicConfig(filename=apex_log_filename,
                            format='%(asctime)s %(levelname)s: %(message)s',
                            datefmt='%m/%d/%Y %I:%M:%S %p',
                            level=logging.DEBUG)
    if hasattr(args, 'func'):
        args.func(args)
    else:
        parser.print_help()
        exit(1)

if __name__ == "__main__":
    main()
