Installation High-Level Overview - Virtual Deployment
=====================================================

The VM nodes deployment operates almost the same way as the bare metal
deployment with a few differences.  ``opnfv-deploy`` still deploys an Undercloud
VM. In addition to the Undercloud VM a collection of VMs (3 control nodes + 2
compute for an HA deployment or 1 control node and 1 compute node for a Non-HA
Deployment) will be defined for the target OPNFV deployment.  The part of the
toolchain that executes IPMI power instructions calls into libvirt instead of
the IPMI interfaces on baremetal servers to operate the power managment.  These
VMs are then provisioned with the same disk images and configuration that
baremetal would be. To RDO Manager these nodes look like they have just built
and registered the same way as bare metal nodes, the main difference is the use
of a libvirt driver for the power management.

Installation Guide - Virtual Deployment
=======================================

This section goes step-by-step on how to correctly install and provision the OPNFV target system to VM nodes.

Install Jumphost
----------------

Follow the instructions in the `Install Bare Metal Jumphost`_ section.

Running ``opnfv-deploy``
------------------------

You are now ready to deploy OPNFV!
``opnfv-deploy`` has virtual deployment capability that includes all of
the configuration nessesary to deploy OPNFV with no modifications.

If no modifications are made to the included configurations the target environment
will deploy with the following architecture:

    - 1 Undercloud VM

    - The option of 3 control and 2 or more compute VMs (HA Deploy / default)
      or 1 control and 1 or more compute VM (Non-HA deploy / pass -n)

    - 2-4 networks: provisioning / internal API, storage, private tenant networking
      and the external network. The storage and tenant networking networks
      can be collapsed onto the provisioning network.

Follow the steps below to execute:

1.  ``sudo opnfv-deploy [ --flat ] -n network_settings.yaml -i inventory.yaml -d deploy_settings.yaml``

2.  It will take approximately 45 minutes to an hour to stand up Undercloud,
    define the target virtual machines, configure the deployment and execute the deployment.
    You will notice different outputs in your shell.

3.  When the deployment is complete you will see "Overcloud Deployed"

Verifying the Setup - VMs
-------------------------

To verify the set you can follow the instructions in the `Verifying the Setup`_ section.

.. _`Install Bare Metal Jumphost`: baremetal.html
.. _`Verifying the Setup`: verification.html
