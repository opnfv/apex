##############################################################################
# Copyright (c) 2017 Feng Pan (fpan@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import git
import logging
import os
from pygerrit2.rest import GerritRestAPI
import re
import shutil
import sys


def clone_fork(args):
    ref = None
    logging.info("Cloning {}".format(args.repo))

    try:
        cm = git.Repo(search_parent_directories=True).commit().message
    except git.exc.InvalidGitRepositoryError:
        logging.debug('Current Apex directory is not a git repo: {}'
                      .format(os.getcwd()))
        cm = ''

    logging.info("Current commit message: {}".format(cm))
    m = re.search('{}:\s*(\S+)'.format(args.repo), cm)

    if m:
        change_id = m.group(1)
        logging.info("Using change ID {} from {}".format(change_id, args.repo))
        rest = GerritRestAPI(url=args.url)
        change_str = "changes/{}?o=CURRENT_REVISION".format(change_id)
        change = rest.get(change_str)
        try:
            assert change['status'] not in 'ABANDONED' 'CLOSED',\
                'Change {} is in {} state'.format(change_id, change['status'])
            if change['status'] == 'MERGED':
                logging.info('Change {} is merged, ignoring...'
                             .format(change_id))
            else:
                current_revision = change['current_revision']
                ref = change['revisions'][current_revision]['ref']
                logging.info('setting ref to {}'.format(ref))
        except KeyError:
            logging.error('Failed to get valid change data structure from url '
                          '{}/{}, data returned: \n{}'
                          .format(change_id, change_str, change))
            raise

    # remove existing file or directory named repo
    if os.path.exists(args.repo):
        if os.path.isdir(args.repo):
            shutil.rmtree(args.repo)
        else:
            os.remove(args.repo)

    ws = git.Repo.clone_from("{}/{}".format(args.url, args.repo),
                             args.repo, b=args.branch)
    if ref:
        git_cmd = ws.git
        git_cmd.fetch("{}/{}".format(args.url, args.repo), ref)
        git_cmd.checkout('FETCH_HEAD')
        logging.info('Checked out commit:\n{}'.format(ws.head.commit.message))


def get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('--debug', action='store_true', default=False,
                        help="Turn on debug messages")
    subparsers = parser.add_subparsers()
    fork = subparsers.add_parser('clone-fork',
                                 help='Clone fork of dependent repo')
    fork.add_argument('-r', '--repo', required=True, help='Name of repository')
    fork.add_argument('-u', '--url',
                      default='https://gerrit.opnfv.org/gerrit',
                      help='Gerrit URL of repository')
    fork.add_argument('-b', '--branch',
                      default='master',
                      help='Branch to checkout')
    fork.set_defaults(func=clone_fork)
    return parser


def main():
    parser = get_parser()
    args = parser.parse_args(sys.argv[1:])
    if args.debug:
        logging_level = logging.DEBUG
    else:
        logging_level = logging.INFO

    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',
                        datefmt='%m/%d/%Y %I:%M:%S %p',
                        level=logging_level)
    if hasattr(args, 'func'):
        args.func(args)
    else:
        parser.print_help()
        exit(1)

if __name__ == "__main__":
    main()
