Deploying Directly from Upstream
================================

When installing the Undercloud and Overcloud, the disk images are now downloaded
directly from upstream artifacts.  Essentially this deployment pulls the latest
RDO overcloud and undercloud artifacts at deploy time.  This option is useful
for being able to pull the latest Queens and other OPNFV components which have
been promoted via a TripleO pipeline and deemed to be stable.

Upstream Deployment Key Features
--------------------------------

In addition to being able to install newer versions of OpenStack, the upstream
deployment option allows the use of a newer version of TripleO, which provides
overcloud container support.  Therefore when deploying from upstream with an
OpenStack version newer than Pike, every OpenStack service (also OpenDaylight)
will be running as a docker container.  Furthermore, deploying upstream gives
the user the flexibility of including any upstream OpenStack patches he/she
may need by simply adding them into the deploy settings file.  The patches will
be applied live during deployment.

Installation Guide - Upstream Deployment
========================================

This section goes step-by-step on how to correctly install and provision the
OPNFV target system using a direct upstream deployment.

Special Requirements for Upstream Deployments
---------------------------------------------

With upstream deployments it is required to have internet access.  In addition,
the upstream artifacts will be cached under the root partition of the jump
host.  It is required to at least have 10GB free space in the root partition
in order to download and prepare the cached artifacts.

Scenarios and Deploy Settings for Upstream Deployments
------------------------------------------------------

The deploy settings and scenarios included with the Gambia release of Apex will
be supported as deemed by the `OPNFV Scenarios in Apex`_ section of this guide.
Each of these scenarios has been tested by Apex over the Gambia release, and
using those deploy settings will control which upstream artifacts are pulled
at deploy time. By specifying different versions of OpenStack, ODL, or other
components in the deploy settings, different upstream artifacts may be downloaded
and are not considered to be supported. For deploying newer versions of components
it is advised to use the master branch of OPNFV Apex as part of our continuous
integration effort to support those components.

Including Upstream Patches with Deployment
------------------------------------------------------

With upstream deployments it is possible to include any pending patch in
OpenStack gerrit with the deployment.  These patches are applicable to either
the undercloud or the overcloud.  This feature is useful in the case where
a developer or user desires to pull in an unmerged patch for testing with a
deployment.  In order to use this feature, include the following in the deploy
settings file, under "global_params" section:

.. code-block:: yaml

     patches:
       undercloud:
         - change-id: <gerrit change id>
           project: openstack/<project name>
           branch:  <branch where commit is proposed>
       overcloud:
         - change-id: <gerrit change id>
           project: openstack/<project name>
           branch:  <branch where commit is proposed>

You may include as many patches as needed.  If the patch is already merged or
abandoned, then it will not be included in the deployment.

Running ``opnfv-deploy``
------------------------

Deploying is similar to the typical method used for baremetal and virtual
deployments with the addition of a few new arguments to the ``opnfv-deploy``
command. The artifacts for each upstream deployment are only
downloaded when a newer version is detected upstream.  In order to explicitly
disable downloading new artifacts from upstream if previous artifacts are
already cached, please use the ``--no-fetch`` argument.

Interacting with Containerized Overcloud
----------------------------------------

Upstream deployments will use a containerized overcloud.  These containers are
Docker images built by the Kolla project.  The Containers themselves are run
and controlled through Docker as root user.  In order to access logs for each
service, examine the '/var/log/containers' directory or use the `docker logs
<container name>`.  To see a list of services running on the node, use the
``docker ps`` command.  Each container uses host networking, which means that
the networking of the overcloud node will act the same exact way as a
traditional deployment.  In order to attach to a container, use this command:
``docker exec -it <container name/id> bin/bash``.  This will login to the
container with a bash shell.  Note the containers do not use systemd, unlike
the traditional deployment model and are instead started as the first process
in the container.  To restart a service, use the ``docker restart <container>``
command.

.. _`OPNFV Scenarios in Apex`: architecture.html#opnfv-scenarios-in-apex
