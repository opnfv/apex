##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

clone_fork () {
    # ARG 1: apex-tripleo-heat-templates
    #        apex-puppet-tripleo
    #        apex-os-net-config
    echo "Cloning $1"

    local changeid=''
    local ref='master'
    local repo='https://gerrit.opnfv.org/gerrit'
    local changeid=$(git log -1 | grep "$1:" | cut -d \  -f 2)

    if [ "$changeid" != "" ]; then
      echo "Using Change ID $changeid from $repo"

      # the project-id and branch can be included in the curl call like this
      #local change=$(curl $repo/changes/$1~$ref~$changeid?o=CURRENT_REVISION | tail -n+2)
      # I don't think the changeids will be ambiguous so let's go like this
      # for more flexibility
      local change=$(curl $repo/changes/$changeid?o=CURRENT_REVISION | tail -n+2)

      # Do not pull from merged branches
      local change_status=$(python -c "import json; print json.loads('''$change'''.replace('\n', '').replace('\r', ''))['status']")
      if [[ ! 'MERGED ABANDONED CLOSED' =~ "$change_status" ]]; then
        ref=$(python -c "import json; print json.loads('''$change'''.replace('\n', '').replace('\r', ''))['current_revision']")
        echo "Setting GitHub Ref to: $ref"
      fi
    fi

    rm -rf $1
    git clone $repo/$1 -b $ref $1
}
