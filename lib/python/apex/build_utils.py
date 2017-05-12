##############################################################################
# Copyright (c) 2017 Feng Pan (fpan@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import git
import logging
import os
from pygerrit2.rest import GerritRestAPI
import re
import shutil


def clone_fork(repo, gerrit_url='https://gerrit.opnfv.org/gerrit',
               branch='master'):
    ref = None
    logging.info("Cloning {}".format(repo))

    try:
        cm = git.Repo(search_parent_directories=True).commit().message
    except git.exc.InvalidGitRepositoryError:
        logging.debug('Current Apex directory is not a git repo: {}'
                      .format(os.getcwd()))
        cm = ''

    logging.info("Current commit message: {}".format(cm))
    m = re.search('{}:\s*(\S+)'.format(repo), cm)

    if m:
        change_id = m.group(1)
        logging.info("Using change ID {} from {}".format(change_id, repo))
        rest = GerritRestAPI(url=gerrit_url)
        change_str = "changes/{}?o=CURRENT_REVISION".format(change_id)
        change = rest.get(change_str)
        try:
            if change['status'] not in 'MERGED' 'ABANDONED' 'CLOSED':
                current_revision = change['current_revision']
                ref = change['revisions'][current_revision]['ref']
                logging.info('setting ref to {}'.format(ref))
        except KeyError:
            logging.error('Failed to get valid change data structure from url '
                          '{}/{}, data returned: \n{}'
                          .format(change_id, change_str, change))
            raise

    # remove existing file or directory named repo
    if os.path.exists(repo):
        if os.path.isdir(repo):
            shutil.rmtree(repo)
        else:
            os.remove(repo)

    ws = git.Repo.clone_from("{}/{}".format(gerrit_url, repo), repo, b=branch)
    if ref:
        git_cmd = ws.git
        git_cmd.fetch("{}/{}".format(gerrit_url, repo), ref)
        git_cmd.checkout('FETCH_HEAD')
        logging.info('Checked out commit:\n{}'.format(ws.head.commit.message))
