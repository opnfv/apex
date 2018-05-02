##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import argparse
import logging
import os
import subprocess
import sys
import uuid
import yaml

from apex.common import utils

CACHE_JOURNAL = 'cache_journal.yaml'
TMP_CACHE = '.cache'
BUILD_ROOT = 'build'
BUILD_LOG_FILE = './apex_build.log'


class ApexBuildException(Exception):
    pass


def create_build_parser():
    build_parser = argparse.ArgumentParser()
    build_parser.add_argument('--debug', action='store_true', default=False,
                              help="Turn on debug messages")
    build_parser.add_argument('-l', '--log-file',
                              default=BUILD_LOG_FILE,
                              dest='log_file', help="Log file to log to")
    build_parser.add_argument('-c', '--cache-dir',
                              dest='cache_dir',
                              default=None,
                              help='Directory to store cache')
    build_parser.add_argument('--iso', action='store_true',
                              default=False,
                              help='Build ISO image')
    build_parser.add_argument('--rpms', action='store_true',
                              default=False,
                              help='Build RPMs')
    build_parser.add_argument('-r', '--release',
                              dest='build_version',
                              help='Version to apply to build '
                                   'artifact label')

    return build_parser


def get_journal(cache_dir):
    """
    Search for the journal file and returns its contents
    :param cache_dir: cache storage directory where journal file is
    :return: content of journal file
    """
    journal_file = "{}/{}".format(cache_dir, CACHE_JOURNAL)
    if os.path.isfile(journal_file) is False:
        logging.info("Journal file not found {}, skipping cache search".format(
            journal_file))
    else:
        with open(journal_file, 'r') as fh:
            cache_journal = yaml.safe_load(fh)
            assert isinstance(cache_journal, list)
            return cache_journal


def get_cache_file(cache_dir):
    """
    Searches for a valid cache entry in the cache journal
    :param cache_dir: directory where cache and journal are located
    :return: name of valid cache file
    """
    cache_journal = get_journal(cache_dir)
    if cache_journal is not None:
        valid_cache = cache_journal[-1]
        if os.path.isfile(valid_cache):
            return valid_cache


def unpack_cache(cache_dest, cache_dir=None):
    if cache_dir is None:
        logging.info("Cache directory not provided, skipping cache unpack")
        return
    elif os.path.isdir(cache_dir) is False:
        logging.info("Cache Directory does not exist, skipping cache unpack")
        return
    else:
        logging.info("Cache Directory Found: {}".format(cache_dir))
        cache_file = get_cache_file(cache_dir)
        if cache_file is None:
            logging.info("No cache file detected, skipping cache unpack")
            return
        logging.info("Unpacking Cache {}".format(cache_file))
        if not os.path.exists(cache_dest):
            os.makedirs(cache_dest)
        try:
            subprocess.check_call(["tar", "xvf", cache_file, "-C", cache_dest])
        except subprocess.CalledProcessError:
            logging.warning("Cache unpack failed")
            return
        logging.info("Cache unpacked, contents are: {}".format(
                     os.listdir(cache_dest)))


def build(build_root, version, iso=False, rpms=False):
    if iso:
        logging.warning("iso is deprecated. Will not build iso and build rpm "
                        "instead.")
        make_targets = ['rpms']
    elif rpms:
        make_targets = ['rpms']
    else:
        logging.warning("Nothing specified to build, and images are no "
                        "longer supported in Apex.  Will only run rpm check")
        make_targets = ['rpms-check']
    if version is not None:
        make_args = ['RELEASE={}'.format(version)]
    else:
        make_args = []
    logging.info('Running make clean...')
    try:
        subprocess.check_call(['make', '-C', build_root, 'clean'])
    except subprocess.CalledProcessError:
        logging.error('Failure to make clean')
        raise
    logging.info('Building targets: {}'.format(make_targets))
    try:
        output = subprocess.check_output(["make"] + make_args + ["-C",
                                         build_root] + make_targets)
        logging.info(output)
    except subprocess.CalledProcessError as e:
        logging.error("Failed to build Apex artifacts")
        logging.error(e.output)
        raise e


def build_cache(cache_source, cache_dir):
    """
    Tar up new cache with unique name and store it in cache storage
    directory.  Also update journal file with new cache entry.
    :param cache_source: source files to tar up when building cache file
    :param cache_dir: cache storage location
    :return: None
    """
    if cache_dir is None:
        logging.info("No cache dir specified, will not build cache")
        return
    cache_name = 'apex-cache-{}.tgz'.format(str(uuid.uuid4()))
    cache_full_path = os.path.join(cache_dir, cache_name)
    os.makedirs(cache_dir, exist_ok=True)
    try:
        subprocess.check_call(['tar', '--atime-preserve', '--dereference',
                               '-caf', cache_full_path, '-C', cache_source,
                               '.'])
    except BaseException as e:
        logging.error("Unable to build new cache tarball")
        if os.path.isfile(cache_full_path):
            os.remove(cache_full_path)
        raise e
    if os.path.isfile(cache_full_path):
        logging.info("Cache Build Complete")
        # update journal
        cache_entries = get_journal(cache_dir)
        if cache_entries is None:
            cache_entries = [cache_name]
        else:
            cache_entries.append(cache_name)
        journal_file = os.path.join(cache_dir, CACHE_JOURNAL)
        with open(journal_file, 'w') as fh:
            yaml.safe_dump(cache_entries, fh, default_flow_style=False)
        logging.info("Journal updated with new entry: {}".format(cache_name))
    else:
        logging.warning("Cache file did not build correctly")


def prune_cache(cache_dir):
    """
    Remove older cache entries if there are more than 2
    :param cache_dir: Cache storage directory
    :return: None
    """
    if cache_dir is None:
        return
    cache_modified_flag = False
    cache_entries = get_journal(cache_dir)
    while len(cache_entries) > 2:
        logging.debug("Will remove older cache entries")
        cache_to_rm = cache_entries[0]
        cache_full_path = os.path.join(cache_dir, cache_to_rm)
        if os.path.isfile(cache_full_path):
            try:
                os.remove(cache_full_path)
                cache_entries.pop(0)
                cache_modified_flag = True
            except OSError:
                logging.warning("Failed to remove cache file: {}".format(
                    cache_full_path))
                break

    else:
        logging.debug("No more cache cleanup necessary")

    if cache_modified_flag:
        logging.debug("Updating cache journal")
        journal_file = os.path.join(cache_dir, CACHE_JOURNAL)
        with open(journal_file, 'w') as fh:
            yaml.safe_dump(cache_entries, fh, default_flow_style=False)


def main():
    parser = create_build_parser()
    args = parser.parse_args(sys.argv[1:])
    if args.debug:
        log_level = logging.DEBUG
    else:
        log_level = logging.INFO
    os.makedirs(os.path.dirname(args.log_file), exist_ok=True)
    formatter = '%(asctime)s %(levelname)s: %(message)s'
    logging.basicConfig(filename=args.log_file,
                        format=formatter,
                        datefmt='%m/%d/%Y %I:%M:%S %p',
                        level=log_level)
    console = logging.StreamHandler()
    console.setLevel(log_level)
    console.setFormatter(logging.Formatter(formatter))
    logging.getLogger('').addHandler(console)
    utils.install_ansible()
    # Since we only support building inside of git repo this should be fine
    try:
        apex_root = subprocess.check_output(
            ['git', 'rev-parse', '--show-toplevel']).decode('utf-8').strip()
    except subprocess.CalledProcessError:
        logging.error("Must be in an Apex git repo to execute build")
        raise
    apex_build_root = os.path.join(apex_root, BUILD_ROOT)
    if os.path.isdir(apex_build_root):
        cache_tmp_dir = os.path.join(apex_root, TMP_CACHE)
    else:
        logging.error("You must execute this script inside of the Apex "
                      "local code repository")
        raise ApexBuildException("Invalid path for apex root: {}.  Must be "
                                 "invoked from within Apex code directory.".
                                 format(apex_root))
    dep_playbook = os.path.join(apex_root,
                                'lib/ansible/playbooks/build_dependencies.yml')
    utils.run_ansible(None, dep_playbook)
    # unpack_cache(cache_tmp_dir, args.cache_dir)
    build(apex_build_root, args.build_version, args.iso, args.rpms)
    # build_cache(cache_tmp_dir, args.cache_dir)
    # prune_cache(args.cache_dir)


if __name__ == '__main__':
    main()
