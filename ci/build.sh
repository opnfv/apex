#!/bin/sh
##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

display_usage ()
{
cat << EOF
$0 Builds the Apex OPNFV Deployment Toolchain

usage: $0 [ -c cache_dir ] -r release_name [ --iso | --rpms ]

OPTIONS:
  -c cache destination - directory of cached files, defaults to ./cache
  -r release name/version of the build result
  --iso build the iso (implies RPMs too)
  --rpms build the rpms
  --no-rpm-check skip the rpm-check
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
MAKE_TARGETS="rpm-check images"

parse_cmdline() {
  while [ "${1:0:1}" = "-" ]
  do
    case "$1" in
        -h|--help)
                display_usage
                exit 0
            ;;
        -c|--cache-dir)
                CACHE_DEST=${2}
                shift 2
            ;;
        -r|--release)
                RELEASE=${2}
                shift 2
            ;;
        --iso )
                MAKE_TARGETS="iso"
                echo "Building opnfv-apex RPMs and ISO"
                shift 1
            ;;
        --rpms )
                MAKE_TARGETS="rpms"
                echo "Buiding opnfv-apex RPMs"
                shift 1
            ;;
        --no-rpm-check )
                if $MAKE_TARGETS =~ "images"; then
                    MAKE_TARGETS="images"
                    echo "Skipping rpm-check step"
                else
                    echo "Cannot skip rpm-check on non-images only build"
                fi
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

run_make() {
  make $MAKE_ARGS -C ${BUILD_BASE} $1
}

parse_cmdline "$@"

if [ -n "$RELEASE" ]; then MAKE_ARGS+="RELEASE=$RELEASE "; fi

# Get the Old Cache
if [ -n "$CACHE_DEST" ]; then
    echo "Retrieving Cache"
    if [ -f $CACHE_DEST/${CACHE_NAME}.tgz ]; then
        rm -rf $BUILD_BASE/$CACHE_DIR
        cp -f $CACHE_DEST/${CACHE_NAME}.tgz $BUILD_BASE/${CACHE_NAME}.tgz
        tar xzf $BUILD_BASE/${CACHE_NAME}.tgz
    elif [ ! -d $BUILD_BASE/$CACHE_DIR ]; then
        mkdir $BUILD_BASE/$CACHE_DIR
    fi
fi

#create build_output for legacy functionality compatibility in jenkins
if [[ ! -d ../build_output  ]]; then
    rm -f ../build_output
    ln -s build/noarch/ ../build_output
fi

# Conditionally execute RPM build checks if the specs change and target is not rpm or iso
if [[ "$MAKE_TARGETS" == "images" ]]; then
    commit_file_list=$(git show --pretty="format:" --name-only)
    if [[ $commit_file_list == *build/Makefile* ]]; then
        # Makefile forces all rpms to be checked
        MAKE_TARGETS+=" rpms-check"
    else
        # Spec files are selective
        if [[ $commit_file_list == *build/opnfv-apex-undercloud.spec* ]]; then
            MAKE_TARGETS+=" undercloud-rpm-check"
        fi
        if [[ $commit_file_list == *build/opnfv-apex.spec* ]]; then
            MAKE_TARGETS+=" common-rpm-check"
        fi
        if [[ $commit_file_list == *build/opnfv-apex.spec* ]]; then
            MAKE_TARGETS+=" opendaylight-rpm-check"
        fi
        if [[ $commit_file_list == *build/opnfv-apex.spec* ]]; then
            MAKE_TARGETS+=" onos-rpm-check"
        fi
        if [[ $commit_file_list == *build/opnfv-apex.spec* ]]; then
            MAKE_TARGETS+=" opendaylight-sfc-rpm-check"
        fi
    fi
fi

# Make sure python is installed
if ! rpm -q python34-devel > /dev/null; then
    sudo yum install -y epel-release
    if ! sudo yum install -y python34-devel; then
        echo "Failed to install python34-devel package..."
        exit 1
    fi
fi

# Execute make against targets
for t in $MAKE_TARGETS; do
    run_make $t
done

echo "Build Complete"

# Build new Cache
if [ -n "$CACHE_DEST" ]; then
    echo "Building Cache"
    tar --atime-preserve --dereference -C $BUILD_BASE -caf $BUILD_BASE/${CACHE_NAME}.tgz $CACHE_DIR
    echo "Copying Cache"
    if [ ! -d $CACHE_DEST ]; then mkdir -p $CACHE_DEST; fi
    cp $BUILD_BASE/${CACHE_NAME}.tgz $CACHE_DEST/${CACHE_NAME}.tgz
fi
echo "Complete"
