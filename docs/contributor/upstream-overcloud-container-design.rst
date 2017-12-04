=======================================
Overcloud Container Design/Architecture
=======================================

This document describes the changes done to implement container deployments in
Apex.

 * OOO container architecture
 * Upstream vs Downstream deployment
 * Apex container deployment overview

OOO container architecture
--------------------------

Typically in OOO each OpenStack service is represented by a TripleO Heat
Template stored under the puppet/services directory in the THT code base.  For
containers, there are new templates created in the docker/services directory
which include templates for most of the previously defined puppet services.
These docker templates in almost all cases inherit their puppet template
counterpart and then build off of that to provide OOO docker specific
configuration.

The containers configuration in OOO is still done via puppet, and config files
are then copied into a host directory to be later mounted in the service
container during deployment.  The docker template contains docker specific
settings to the service, including what files to mount into the container,
along with which puppet resources to execute, etc.  Note, the puppet code is
still stored locally on the host, while the service python code is stored in
the container image.

RDO has its own registry which stores the Docker images per service to use in
deployments.  The container image is usually just a CentOS 7 container with the
relevant service RPM installed.

In addition, Ceph no longer uses puppet to deploy.  puppet-ceph was previously
used to configure Ceph on the overcloud, but has been replaced with
Ceph-Ansible.  During container deployment, the undercloud calls a mistral
workflow to initiate a Ceph-Ansible playbook that will download the Ceph Daemon
container image to the overcloud and configure it.

Upstream vs. Downstream deployment
----------------------------------

In Apex we typically build artifacts and then deploy from them.  This works in
the past as we usually modify disk images (qcow2s) with files or patches and
distribute them as RPMs.  However, with containers space becomes an issue.  The
size of each container image ranges from 800 MB to over 2GB.  This makes it
unfeasible to download all of the possible images and store them into a disk
image for distribution.

Therefore for container deployments the only option is to deploy using
upstream.  This means that only upstream undercloud/overcloud images are pulled
at deploy time, and the required containers are docker pulled during deployment
into the undercloud.  For upstream deployments the modified time of the
RDO images are checked and cached locally, to refrain from unnecessary
downloading of artifacts.  Also, the optional '--no-fetch' argument may be
provided at deploy time, to ignore pulling any new images, as long as previous
artifacts are cached locally.

Apex container deployment
-------------------------

For deploying containers with Apex, a new deploy setting is available,
'containers'.  When this flag is used, along with '--upstream' the following
workflow occurs:

  1. The upstream RDO images for undercloud/overcloud are checked and
     downloaded if necessary.
  2. The undercloud VM is installed and configured as a normal deployment.
  3. The overcloud prep image method is called which is modified now for
     patches and containers.  The method will now return a set of container
     images which are going to be patched.  These can be either due to a change
     in OpenDaylight version for example, or patches included in the deploy
     settings for the overcloud that include a python path.
  4. During the overcloud image prep, a new directory in the Apex tmp dir is
     created called 'containers' which then includes sub-directories for each
     docker image which is being patched (for example, 'containers/nova-api').
  5. A Dockerfile is created inside of the directory created in step 4, which
     holds Dockerfile operations to rebuild the container with patches or any
     required changes.  Several container images could be used for different
     services inside of an OS project.  For example, there are different images
     for each nova service (nova-api, nova-conductor, nova-compute). Therefore
     a lookup is done to figure out all of the container images that a
     hypothetically provided nova patch would apply to.  Then a directory and
     Dockerfile is created for each image.  All of this is tar'ed and
     compressed into an archive which will be copied to the undercloud.
  6. Next, the deployment is checked to see if a Ceph devices was provided in
     Apex settings.  If it is not, then a persistent loop device is created
     in the overcloud image to serve as storage backend for Ceph OSDs.  Apex
     previously used a directory '/srv/data' to serve as the backend to the
     OSDs, but that is no longer supported with Ceph-Ansible.
  7. The deployment command is then created, as usual, but with minor changes
     to add docker.yaml and docker-ha.yaml files which are required to deploy
     containers with OOO.
  8. Next a new playbook is executed, 'prepare_overcloud_containers.yaml',
     which includes several steps:

     a. The previously archived docker image patches are copied and unpacked
        into /home/stack.
     b. 'overcloud_containers' and 'sdn_containers' image files are then
        prepared which are basically just yaml files which indicate which
        docker images to pull and where to store them.  Which in our case is a
        local docker registry.
     c. The docker images are then pulled and stored into the local registry.
        The reason for using a local registry is to then have a static source
        of images that do not change every time a user deploys.  This allows
        for more control and predictability in deployments.
     d. Next, the images in the local registry are cross-checked against
        the images that were previously collected as requiring patches.  Any
        image which then exists in the local registry and also requires changes
        is then rebuilt by the docker build command, tagged with 'apex' and
        then pushed into the local registry.  This helps the user distinguish
        which containers have been modified by Apex, in case any debugging is
        needed in comparing upstream docker images with Apex modifications.
     e. Then new OOO image files are created, to indicate to OOO that the
        docker images to use for deployment are the ones in the local registry.
        Also, the ones modified by Apex are modified with the 'apex' tag.
     f. The relevant Ceph Daemon Docker image is pulled and pushed into the
        local registry for deployment.
  9. At this point the OOO deployment command is initiated as in regular
     Apex deployments.  Each container will be started on the overcloud and
     puppet executed in it to gather the configuration files in Step 1.  This
     leads to Step 1 taking longer than it used to in non-containerized
     deployments.  Following this step, the containers are then brought up in
     their regular step order, while mounting the previously generated
     configuration files.
