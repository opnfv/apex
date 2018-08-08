Installation High-Level Overview - Virtual Deployment
=====================================================

Deploying virtually is an alternative deployment method to bare metal, where
only a single bare metal Jump Host server is required to execute deployment.
In this deployment type, the Jump Host server will host the undercloud VM along
with any number of OPNFV overcloud control/compute nodes.  This deployment type
is useful when physical resources are constrained, or there is a desire to
deploy a temporary sandbox environment.

The virtual deployment operates almost the same way as the bare metal
deployment with a few differences mainly related to power management.
``opnfv-deploy`` still deploys an undercloud VM. In addition to the undercloud
VM a collection of VMs (3 control nodes + 2 compute for an HA deployment or 1
control node and 0 or more compute nodes for a Non-HA Deployment) will be
defined for the target OPNFV deployment.  All overcloud VMs are registered
with a Virtual BMC emulator which will service power management (IPMI)
commands.  The overcloud VMs are still provisioned with the same disk images
and configuration that baremetal would use. Using 0 nodes for a virtual
deployment will automatically deploy "all-in-one" nodes which means the compute
will run along side the controller in a single overcloud node. Specifying 3
control nodes will result in a highly-available service model.

To Triple-O these nodes look like they have just built and registered the same
way as bare metal nodes, the main difference is the use of a libvirt driver for
the power management.  Finally, the default network settings file will deploy without
modification.  Customizations are welcome but not needed if a generic set of
network settings are acceptable.

Installation Guide - Virtual Deployment
=======================================

This section goes step-by-step on how to correctly install and provision the
OPNFV target system to VM nodes.

Special Requirements for Virtual Deployments
--------------------------------------------

In scenarios where advanced performance options or features are used, such
as using huge pages with nova instances, DPDK, or iommu; it is required to
enabled nested KVM support.  This allows hardware extensions to be passed to
the overcloud VMs, which will allow the overcloud compute nodes to bring up
KVM guest nova instances, rather than QEMU.  This also provides a great
performance increase even in non-required scenarios and is recommended to be
enabled.

During deployment the Apex installer will detect if nested KVM is enabled,
and if not, it will attempt to enable it; while printing a warning message
if it cannot.  Check to make sure before deployment that Nested
Virtualization is enabled in BIOS, and that the output of ``cat
/sys/module/kvm_intel/parameters/nested`` returns "Y".  Also verify using
``lsmod`` that the kvm_intel module is loaded for x86_64 machines, and
kvm_amd is loaded for AMD64 machines.

Install Jump Host
-----------------

Follow the instructions in the `Install Bare Metal Jump Host`_ section.

Running ``opnfv-deploy``
------------------------

You are now ready to deploy OPNFV!
``opnfv-deploy`` has virtual deployment capability that includes all of
the configuration necessary to deploy OPNFV with no modifications.

If no modifications are made to the included configurations the target
environment will deploy with the following architecture:

    - 1 undercloud VM

    - The option of 3 control and 2 or more compute VMs (HA Deploy / default)
      or 1 control and 0 or more compute VMs (Non-HA deploy)

    - 1-5 networks: provisioning, private tenant networking, external, storage
      and internal API. The API, storage and tenant networking networks can be
      collapsed onto the provisioning network.

Follow the steps below to execute:

1.  ``sudo opnfv-deploy -v [ --virtual-computes n ]
    [ --virtual-cpus n ] [ --virtual-ram n ]
    -n network_settings.yaml -d deploy_settings.yaml``
    Note it can also be useful to run the command with the ``--debug``
    argument which will enable a root login on the overcloud nodes with
    password: 'opnfvapex'.  It is also useful in some cases to surround the
    deploy command with ``nohup``.  For example:
    ``nohup <deploy command> &``, will allow a deployment to continue even if
    ssh access to the Jump Host is lost during deployment. By specifying
    ``--virtual-computes 0``, the deployment will proceed as all-in-one.

2.  It will take approximately 45 minutes to an hour to stand up undercloud,
    define the target virtual machines, configure the deployment and execute
    the deployment.  You will notice different outputs in your shell.

3.  When the deployment is complete the IP for the undercloud and a url for the
    OpenStack dashboard will be displayed

Verifying the Setup - VMs
-------------------------

To verify the set you can follow the instructions in the `Verifying the Setup`_
section.

.. _`Install Bare Metal Jump Host`: baremetal.html#install-bare-metal-jump-host
.. _`Verifying the Setup`: verification.html#verifying-the-setup
