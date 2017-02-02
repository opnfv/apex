##############################################################################
# Copyright (c) 2016 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
import os
import subprocess

QUICKSTART_REQUIREMENTS = [ '-r', 'requirements.txt']
#                            '-r', 'quickstart-extras-requirements.txt']

QUICKSTART_DEFAULTS = 'config/quickstart_defaults.yaml'

def deploy_quickstart(args, deploy_file, network_file, inventory_file):
    """
    Will invoke quickstart.sh with the appropriate args to deploy tripleo
    using quickstart with Apex modifications
    """

    # TODO package quickstart to our deploy dir so we don't need to clone
    # (needed for offline installs)
    bd = args.deploy_dir

    # Clone tripleo-quickstart if it's not already found in deploy
    # directory this should only really be used for development
    if 'tripleo-quickstart' not in os.listdir(bd):
        command = ['git', 'clone', args.quickstart_repo,
               basedir('tripleo-quickstart', bd)]
        subprocess.call(command)

        command = ['git', 'checkout', args.quickstart_ref]
        subprocess.Popen(command, cwd=bd)

    # bash quickstart.sh -v $PLAYBOOK $REQUIREMENTS $NETWORK $DEPLOY
    # $INVENTORY $VIRTUAL $CONFIG --tags all --teardown all -n -X $VIRTHOST

    command = ['./quickstart.sh']

    if args.debug:
        command.append('-v')

    # this doesn't need the basedir since it's copied within the virtual env
    command.append('-p')
    command.append(args.quickstart_playbook)

    for r in QUICKSTART_REQUIREMENTS:
        command.append(r)

    command.append('-r')
    command.append(basedir('contrib/apex-requirements.txt', bd))

    command.append('-e')
    command.append("apex_network_settings_file="+basedir(network_file, bd))
    command.append('-e')
    command.append("apex_deploy_settings_file="+basedir(deploy_file, bd))

    if inventory_file:
        command.append('-e')
        command.append(basedir(inventory_file, bd))

    command.append('-e')
    if args.virtual:
        command.append('apex_virtual=True')
    else:
        command.append('apex_virtual=False')

    command.append('-c')
    command.append(basedir(QUICKSTART_DEFAULTS, bd))

    command.append('--tags')
    command.append('all')

    # This sets the openstack release to be used.
    command.append('-R')
    command.append('ocata')

    command.append('--teardown')
    command.append('all')

    command.append('-n')
    command.append('-X')

    command.append(args.virthost)

    # runs tripleo-quickstart's quickstart.sh
    logging.debug("Quickstart command: {}".format(" ".join(command)))
    subprocess.Popen(command, cwd=basedir('tripleo-quickstart',bd))

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

    deploy.add_argument('virthost',
                        help='Target machine on which to install Apex')

    deploy.add_argument('-b', '--base-directory',
                              default=os.getcwd(),
                              dest='base_directory',
                              help='Apex Directory under which to find config')

    deploy.add_argument('-n', '--network-settings-file',
                              default='network-settings.yaml',
                              dest='network_settings',
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
                              default="QUICKSTART_DEFAULTS",
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

    deploy.add_argument('--debug', action='store_true', default=False,
                        help="Turn on debug messages")
    deploy.add_argument('-l', '--log-file', default='/var/log/apex/apex.log',
                        dest='log_file', help="Log file to log to")

    deploy.set_defaults(func=apex_deploy)

    return parser

def basedir(path, base):
    if path[0] != '/':
        return base + '/' + path
    else:
        return path
