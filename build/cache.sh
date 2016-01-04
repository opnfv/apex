#!/bin/sh
##############################################################################
# Copyright (c) 2016 Red Hat Inc.
# Dan Radez <dradez@redhat.com>
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

CACHE_DIR="$(pwd)/cache"

# Make sure the cache dir exists
function cache_dir {
    if [ ! -d $CACHE_DIR/ ]; then mkdir $CACHE_DIR/; fi
    if [ ! -f $CACHE_DIR/.cache ]; then touch $CACHE_DIR/.cache; fi
    echo "Cache Dir: $CACHE_DIR"
}

function cache_git_tar {
    echo "cache_git_tar git ls-remote"
}

# $1 = download url
# $2 = filename to write to
function curl_file {
    echo "Downloading $1"
    echo "Cache location: $CACHE_DIR/$2"
    curl -L $1 > $CACHE_DIR/$2
    sed -i "/$2/d" $CACHE_DIR/.cache
    echo "$(md5sum $CACHE_DIR/$2) $2" >> $CACHE_DIR/.cache
}

# $1 =  download url
function populate_cache {
    cache_dir

    # get the file name
    filename="${1##*/}"

    # check if the cache file exists
    # and if it has an md5 compare that
    echo "Checking cache file: $1"
    if [ ! -f $CACHE_DIR/${filename} ]; then
        curl_file $1 $filename
    else
        remote_md5="$(curl -L ${1}.md5 | awk {'print $1'})"
        if [ -z "$remote_md5" ]; then
            echo "Got empty MD5 from remote for $filename, skipping MD5 check"
        elif [ "$remote_md5" != "$(grep ${filename} $CACHE_DIR/.cache | awk {'print $1'})" ]; then
            curl_file $1 $filename
        fi
    fi
}

# $1 = filename to get from cache
function get_cached_file {
  cp -f $CACHE_DIR/$1 .
}
