##############################################################################
# Copyright (c) 2017 Tim Rozet (trozet@redhat.com) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


class ApexDeployException(Exception):
    pass


class JumpHostNetworkException(Exception):
    pass


class ApexCleanException(Exception):
    pass


class ApexBuildException(Exception):
    pass


class SnapshotDeployException(Exception):
    pass


class OvercloudNodeException(Exception):
    pass


class FetchException(Exception):
    pass
