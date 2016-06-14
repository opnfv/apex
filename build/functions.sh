##############################################################################
# Copyright (c) 2016 Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

clone_fork () {
    # ARG 1: opnfv-tht or opnfv-python-triplo
    echo "Cloning $1"

    # Use apex tripleo-heat-templates fork
    local ghcreds=""
    local pr_num=""
    local ref="stable/colorado"
    local repo="https://github.com/trozet/$1"

    if git log -1 | grep "${1}-pr:" | grep -o '[0-9]*'; then
      pr_num=$(git log -1 | grep "${1}-pr:" | grep -o '[0-9]*')
    fi

    if [ "$pr_num" != "" ]; then
      echo "Using pull request $pr_num from $repo"
      # Source credentials since we are rate limited to 60/day
      if [ -f ~/.githubcreds ]; then
        source ~/.githubcreds
        ghcreds=" -u $GHUSERNAME:$GHACCESSTOKEN"
      fi

      PR=$(curl $ghcreds https://api.github.com/repos/trozet/$1/pulls/$pr_num)

      # Do not pull from merged branches
      MERGED=$(python -c "import json; print json.loads('''$PR'''.replace('\n', '').replace('\r', ''))['merged']")
      if [ "$MERGED" == "False" ]; then
        ref=$(python -c "import json; print json.loads('''$PR'''.replace('\n', '').replace('\r', ''))['head']['ref']")
        echo "Setting GitHub Ref to: $REF"
        repo=$(python -c "import json; print json.loads('''$PR'''.replace('\n', '').replace('\r', ''))['head']['repo']['clone_url']")
        echo "Setting GitHub URL to: $repo"
      fi
    fi

    rm -rf $1
    git clone $repo -b $ref $1
}
