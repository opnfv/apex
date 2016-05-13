import os
import urllib2
import logging

import yaml

"""
Utilities for basic file handling
"""

logger = logging.getLogger('file_utils')


def file_exists(file_path):
    """
    Returns True if the image file already exists and throws an exception if the path is a directory
    :return:
    """
    if os.path.exists(file_path):
        if os.path.isdir(file_path):
            return False
        return os.path.isfile(file_path)
    return False


def download(url, dest_path):
    """
    Download a file to a destination path given a URL
    :rtype : File object
    """
    name = url.rsplit('/')[-1]
    dest = dest_path + '/' + name
    try:
        # Override proxy settings to use localhost to download file
        proxy_handler = urllib2.ProxyHandler({})
        opener = urllib2.build_opener(proxy_handler)
        urllib2.install_opener(opener)
        response = urllib2.urlopen(url)
    except (urllib2.HTTPError, urllib2.URLError):
        raise Exception

    with open(dest, 'wb') as f:
        f.write(response.read())
    return f


def read_yaml(config_file_path):
    """
    Reads the yaml file and returns a dictionary object representation
    :param config_file_path: The file path to config
    :return: a dictionary
    """
    logger.info('Attempting to load configuration file - ' + config_file_path)
    with open(config_file_path) as config_file:
        config = yaml.safe_load(config_file)
        logger.info('Loaded configuration')
    config_file.close()
    logger.info('Closing configuration file')
    return config
