#!/bin/bash
set -e
#!/bin/sh
##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

display_usage ()
{
cat << EOF
$0 Builds the Apex OPNFV Deployment Toolchain

usage: $0 [ -c cache_dir ] -r release_name [ --iso | --rpms ]

OPTIONS:
  -c cache destination - file name generated from the md5sum cached files, defaults to ./cache
  -r release name/version of the build result
  -D Use development builds of OpenStack, defaults to stable
  --iso build the iso (implies RPMs too)
  --rpms build the rpms
  --debug enable debug
  -h help, prints this help text

Example:
build -c file:///tmp/cache -r dev123
EOF
}

BUILD_BASE=$(readlink -e ../build/)
CACHE_DEST=""
CACHE_DIR="cache"
CACHE_NAME="apex-cache"
MAKE_TARGET="images"

parse_cmdline() {
  while [ "${1:0:1}" = "-" ]
  do
    case "$1" in
        -h|--help)
                display_usage
                exit 0
            ;;
        -c|--cache-dir)
                CACHE_DEST=${1}
                shift 1
            ;;
        -r|--release)
                RELEASE=${1}
                shift 1
            ;;
        --iso )
                MAKE_TARGET="iso"
                echo "Building opnfv-apex RPMs and ISO"
                shift 1
            ;;
        --rpms )
                MAKE_TARGET="rpms"
                echo "Buiding opnfv-apex RPMs"
                shift 1
            ;;
        --debug )
                debug="TRUE"
                echo "Enable debug output"
                shift 1
            ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done

}

parse_cmdline

if [ -n "$RELEASE" ]; then MAKE_ARGS+="RELEASE=$RELEASE "; fi
if [[ $USE_MASTER == 1 ]]; then MAKE_ARGS+="USE_MASTER=-master "; fi

# Get the Old Cache
if [ -n "$CACHE_DEST" ]; then
    echo "Retrieving Cache"
    if [ -f $CACHE_DEST/${CACHE_NAME}.tgz ]; then
        rm -rf $BUILD_BASE/$CACHE_DIR
        cp $CACHE_DEST $BUILD_BASE
        tar xzf $BUILD_BASE/${CACHE_NAME}.tgz
    elif [ ! -d $BUILD_BASE/$CACHE_DIR ]; then
        mkdir $BUILD_BASE/$CACHE_DIR
    fi 
fi

# Execute Make
make -C ${BUILD_BASE} $MAKE_TARGET
echo "Build Complete"

# Build new Cache
if [ -n "$CACHE_DEST" ]; then
    echo "Building Cache"
    tar --atime-preserve --dereference -C $BUILD_BASE -caf $BUILD_BASE/${CACHE_NAME}.tgz $CACHE_DIR
    echo "Copying Cache"
    cp $BUILD_BASE/${CACHE_NAME}.tgz $CACHE_DEST/${CACHE_NAME}.tgz
fi
echo "Complete"
