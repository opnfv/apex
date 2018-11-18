==================================================================================
APEX on AARCH64
==================================================================================

This document describes the changes needed to deploy OPNFV-APEX on aarch64
 * General considerations
 * Creating undercloud and overcloud images using DIB
 * Creating Kolla containers

General considerations
--------------------------

OPNFV - APEX relies on artifacts created by the OOO project.

Those artifacts are:

1. Openstack packages, found in delorean_.

   .. _delorean: http://www.python.org/

2. UC and OC images created by rdo and found in images_.

  .. _images: https://images.rdoproject.org/master/rdo_trunk/current-tripleo-rdo-internal/

3. The containerized version of the openstack services found in docker.io_.

   .. _docker.io: https://hub.docker.com/r/tripleomaster/

All the above artifacts are x86_64 only and as a result cannot be used by APEX on aarch64
As a result the user needs to create the Images locally before attempting to deploy.
The only supported scenario is 'os-nosdn-rocky-ha'.


Creating undercloud and overcloud images using DIB
--------------------------------------------------
In order to create that image DIB_ must be used. DIB can either be built from source or use yum to be installed.

.. _DIB: https://github.com/openstack/diskimage-builder

It is important to use a fairly late version of DIB to support UEFI systems. The version currently on epel does NOT have support for UEFI. The version on delorian (15.01) works just fine. DIB uses a YAML file from the user which describes how the
image should look like. The original yaml from rdo is here_:


.. _here: https://github.com/openstack/tripleo-common/blob/master/image-yaml/overcloud-images.yaml

The equivelant yaml files for aarch64  are included in the apex repo.
The UC and OC images are very similar in terms of packages. The major difference is the partition table in EFI so for the undercloud, that has to provided as an environmental variable. 

.. code-block:: python

    export DIB_BLOCK_DEVICE_CONFIG="

    - local_loop:
      name: image0

    - partitioning:
      base: image0
      label: gpt
      partitions:
      - name: ESP
        type: 'EF00'
        size: 64MiB
        mkfs:
          type: vfat
          mount:
            mount_point: /boot/efi
            fstab:
              options: "defaults"
              fsck-passno: 1
    - name: root
      type: '8300'
      size: 50GiB
      mkfs:
        type: ext4
        mount:
          mount_point: /
          fstab:
            options: "defaults"
            fsck-passno: 1
    "

    export DIB_YUM_REPO_CONF+="/etc/yum.repos.d/delorean-deps-rocky.repo /etc/yum.repos.d/delorean-rocky.repo /etc/yum.repos.d
                               /epel.repo "
    openstack --debug overcloud image build --config-file undercloud_rocky.yaml --output-directory ./


The overcloud is built in a similar way.

.. code-block:: python

    export DIB_YUM_REPO_CONF+="/etc/yum.repos.d/delorean-deps-rocky.repo /etc/yum.repos.d/delorean-rocky.repo /etc/yum.repos.d
                               /epel.repo "
    openstack --debug overcloud image build --config-file overcloud_queens_rootfs.yaml --output-directory ./



Apex container deployment
-------------------------
Similarly the containers provided by OOO are for x86 only. Containers for apex on aarch64 for the Rocky release can
be found in armbandapex_.

.. _armbandapex: https://registry.hub.docker.com/v2/repositories/armbandapex/

A user who wishes to rebuild the containers can easily do so by sing Kolla. An example kolla.conf and the command to build the containers is given bellow.


.. code-block:: python

    [DEFAULT]

    base=centos
    type=binary
    namespace="private docker.io repository"
    tag=current-tripleo-rdo
    rpm_setup_config=ceph.repo,epel.repo,delorean-deps.repo,delorean.repo
    push=True



.. code-block:: python

    openstack overcloud container image build --config-file /usr/share/tripleo-common/container-images/overcloud_containers.yaml
    --kolla-config-file /etc/kolla/kolla-build.conf


