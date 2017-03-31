#!/bin/sh
##############################################################################
# Copyright (c) 2016 Red Hat Inc.
# Dan Radez <dradez@redhat.com>
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
source ./variables.sh

# Make sure the cache dir exists
function cache_dir {
    if [ -f $CACHE_DIR ]; then rm -rf $CACHE_DIR; fi
    if [ ! -d $CACHE_DIR/ ]; then mkdir $CACHE_DIR/; fi
    if [ ! -f $CACHE_DIR/$CACHE_HISTORY ]; then touch $CACHE_DIR/$CACHE_HISTORY; fi
    echo "Cache Dir: $CACHE_DIR"
}

# $1 = download url
# $2 = filename to write to
function curl_file {
    if [ -f $CACHE_DIR/$2 ]; then
        echo "Removing stale $2"
        rm -f $CACHE_DIR/$2
    fi
    if [ -f $CACHE_DIR/$2 ]; then
    fi
    echo "Downloading $1"
    echo "Cache download location: $CACHE_DIR/$2"
    until curl -C- -L -o $CACHE_DIR/$2 $1  || (( count++ >= 20 )); do
        echo -n '' #do nothing, we just want to loop
    done
    sed -i "/$2/d" $CACHE_DIR/$CACHE_HISTORY
    echo "$(md5sum $CACHE_DIR/$2) $2" >> $CACHE_DIR/$CACHE_HISTORY
}

# $1 =  download url
# $2 =  remote md5
function populate_cache {
    local my_md5
    cache_dir

    # get the file name
    filename="${1##*/}"
    # copy passed in md5
    remote_md5=$2

    # check if the cache file exists
    # and if it has an md5 compare that
    echo "Checking if cache file exists: ${filename}"
    if [ ! -f $CACHE_DIR/${filename} ]; then
        echo "Cache file: ${CACHE_DIR}/${filename} missing...will download..."
        curl_file $1 $filename
    else
        echo "Cache file exists...comparing MD5 checksum"
        if [ -z "$remote_md5" ]; then
            remote_md5="$(curl -sf -L ${1}.md5 | awk {'print $1'})"
        fi
        if [ -z "$remote_md5" ]; then
            echo "Got empty MD5 from remote for $filename, skipping MD5 check"
            curl_file $1 $filename
        else
            my_md5=$(grep ${filename} ${CACHE_DIR}/${CACHE_HISTORY} | awk {'print $1'})
            if [ -z "$my_md5" ]; then
                echo "${filename} missing in ${CACHE_HISTORY} file. Caculating md5..."
                my_md5=$(md5sum ${CACHE_DIR}/${filename} | awk {'print $1'})
            fi
            if [ "$remote_md5" != "$my_md5" ]; then
                echo "MD5 mismatch, local cache file MD5 is ${my_md5}"
                echo "              remote cache file MD5 is ${remote_md5}"
                echo "Downloading $filename"
                curl_file $1 $filename
            else
              echo "Will use cache for ${filename}"
            fi
        fi
    fi
}
