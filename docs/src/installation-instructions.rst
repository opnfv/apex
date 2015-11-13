========================================================================================================
OPNFV Installation instructions for the Bramaputra release of OPNFV when using Apex as a deployment tool
========================================================================================================


.. contents:: Table of Contents
   :backlinks: none


Abstract
========

This document describes how to install the Bramaputra release of OPNFV when
using Apex as a deployment tool covering it's limitations, dependencies
and required system resources.

License
=======
Bramaputra release of OPNFV when using Apex as a deployment tool Docs
(c) by Tim Rozet (Red Hat) and Dan Radez (Red Hat)

Bramaputra release of OPNFV when using Apex as a deployment tool Docs
are licensed under a Creative Commons Attribution 4.0 International License.
You should have received a copy of the license along with this.
If not, see <http://creativecommons.org/licenses/by/4.0/>.

Version history
===================

+--------------------+--------------------+--------------------+---------------------------+
| **Date**           | **Ver.**           | **Author**         | **Comment**               |
|                    |                    |                    |                           |
+--------------------+--------------------+--------------------+---------------------------+
| 2015-09-17         | 1.0.0              | Dan Radez          | Rewritten for             |
|                    |                    | (Red Hat)          | Apex/RDO Manager support  |
+--------------------+--------------------+--------------------+---------------------------+
| 2015-06-03         | 0.0.4              | Ildiko Vancsa      | Minor changes             |
|                    |                    | (Ericsson)         |                           |
+--------------------+--------------------+--------------------+---------------------------+
| 2015-06-02         | 0.0.3              | Christopher Price  | Minor changes &           |
|                    |                    | (Ericsson AB)      | formatting                |
+--------------------+--------------------+--------------------+---------------------------+
| 2015-05-27         | 0.0.2              | Christopher Price  | Minor changes &           |
|                    |                    | (Ericsson AB)      | formatting                |
+--------------------+--------------------+--------------------+---------------------------+
| 2015-05-07         | 0.0.1              | Tim Rozet          | First draft               |
|                    |                    | (Red Hat)          |                           |
+--------------------+--------------------+--------------------+---------------------------+


Introduction
============

This document describes the steps to install an OPNFV Bramaputra reference
platform, as defined by the Genesis Project using the Apex installer.

The audience is assumed to have a good background in networking
and Linux administration.

Preface
=======

Apex uses the RDO Manager Open Source project as a server provisioning tool.
RDO Manager is the RDO Project implimentation of OpenStack's Triple-O project.
The Triple-O image based life cycle installation tool provisions an OPNFV
Target System (3 controllers, n number of compute nodes) with OPNFV specific
configuration provided by the Apex deployment tool chain.

The Apex deployment artifacts contain the necessary tools to deploy and
configure an OPNFV target system using the Apex deployment toolchain.
These artifacts offer the choice of using the Apex bootable ISO
(``bramaputra.2016.1.0.apex.iso``) to both install CentOS 7 and the
nessesary materials to deploy or the Apex RPM (``opnfv-apex.rpm``)
which expects installation to a CentOS 7 libvirt enabled host. The RPM
contains a collection of configuration file, prebuilt disk images,
and the automatic deployment script (``opnfv-deploy``).

An OPNFV install requires a "Jumphost" in order to operate.  The bootable
ISO will allow you to install a customized CentOS 7 release to the Jumphost,
which includes the required packages needed to run ``opnfv-deploy``.
If you already have a Jumphost with CentOS 7 installed, you may choose to
skip the ISO step and simply install the (``opnfv-apex.rpm``) RPM. The RPM
is the same RPM included in the ISO and includes all the necessary disk
images and configuration files to execute an OPNFV deployment. Either method
will prepare a host to the same ready state for OPNFV deployment.

``opnfv-deploy`` instantiates an RDO Manager Instack VM server using libvirt
as its provider.  This VM is then configured and used to provision the
OPNFV target deployment (3 controllers, n compute nodes).  These nodes can
be either virtual or bare metal. This guide contains instructions for
installing either method.

Triple-O Deployment Architecture
================================

Apex is based on RDO Manager which is the RDO Project's implimentation of
the OpenStack Triple-O project.  It is important to understand the basics
of a Triple-O deployment to help make decisions that will assist in
successfully deploying OPNFV.

Triple-O stands for OpenStack On OpenStack.  This means that OpenStack
will be used to install OpenStack. The target OPNFV deployment is an
OpenStack cloud with NFV features built-in that will be deployed by a
smaller all-in-one deployment of OpenStack.  In this deployment
methodology there are two OpenStack installations. They are referred
to as the undercloud and the overcloud. The undercloud is used to
deploy the overcloud.

The undercloud is the all-in-one installation of OpenStack that includes
baremetal provisioning.  RDO Manager's deployment of the undercloud is
call Instack. Instack will be deployed as a virtual machine on a jumphost.
This VM is pre-built and distributed as part of the Apex RPM.

The overcloud is OPNFV. Configuration will be passed into Instack and
Instack will use OpenStack's orchestration component call Heat to 
execute a deployment will provision the target nodes to become OPNFV.



Setup Requirements
==================

Jumphost Requirements
---------------------

The Jumphost requirements are outlined below:

1.     CentOS 7 (from ISO or self-installed).

2.     Root access.

3.     libvirt virtualization support.

4.     minimum 2 networks and maximum 6 networks trunked or tagged with IP addresses. This is virtualized for a VM
       deployment.

5.     The Bramaputra Apex RPM.

6.     16 GB of RAM for a bare metal deployment, 56 GB of RAM for a VM deployment.

Network Requirements
--------------------

Network requirements include:

1.     No DHCP or TFTP server running on networks used by OPNFV.

2.     2-6 separate networks (trunked or tagged) with connectivity between Jumphost and nodes.

       -  Control Plane Network (Provisioning)

       -  External Network

       -  Internal API Network*

       -  Storage Management Network*

       -  Storage Network*

       -  Tenant Networking Network*

3.     Lights out OOB network access from Jumphost with IPMI node enabled (bare metal deployment only).

4.     Admin or public network has Internet access, meaning a gateway and DNS availability.

| `*` *These networks can be combined with each other or all combined on the OOB Mgmt network.*
| `*` *Non-External networks will be consolidated to the OOB management network if not specifically configured.*

Bare Metal Node Requirements
----------------------------

Bare metal nodes require:

1.     IPMI enabled on OOB interface for power control.

2.     BIOS boot priority should be PXE first then local hard disk.

3.     BIOS PXE interface should include OOB network mentioned above.

Execution Requirements (Bare Metal Only)
----------------------------------------

In order to execute a deployment, one must gather the following information:

1.     IPMI IP addresses for the nodes.

2.     IPMI login information for the nodes (user/pass).

3.     MAC address of admin interfaces on nodes.

4.     MAC address of private interfaces on 3 nodes that will be controllers.


Installation High-Level Overview - Bare Metal Deployment
========================================================

The setup presumes that you have 6 bare metal servers and have already setup network
connectivity on at least 2 interfaces for all servers via a TOR switch or other
network implementation.

The physical TOR switches are **not** automatically configured from the OPNFV reference
platform.  All the networks involved in the OPNFV infrastructure as well as the provider
networks and the private tenant VLANs needs to be manually configured.

The Jumphost can be installed using the bootable ISO or by other means including the
(``opnfv-apex``) RPM and virtualization capabilities.  The Jumphost should then be
configured with an IP gateway on its admin or public interface and configured with a
working DNS server.  The Jumphost should also have routable access to the lights out network.

``opnfv-deploy`` is then executed in order to deploy the Instack VM.  ``opnfv-deploy`` uses
two configuration files in order to know how to install and provision the OPNFV target system.
The information gathered under section `Execution Requirements (Bare Metal Only)`_ is put
into the JSON file (``instackenv.json``) configuration file.  Networking definitions gathered
under section `Network Requirements`_ are put into the JSON file
(``network-environment.yaml``).  ``opnfv-deploy`` will boot the Instack VM and load the target
deployment configuration into the provisioning toolchain.  This includes MAC address, IPMI,
Networking Environment and OPNFV deployment options.

Once configuration is loaded and Instack is configured it will then reboot the nodes via IPMI.
The nodes should already be set to PXE boot first off the admin interface.  The nodes will
first PXE off of the Instack PXE server and go through a discovery/introspection process.

After introspection Instack will execute a Heat Stack Deployment to being node provisioning
and configuration.  The nodes will reboot and PXE again off the Instack PXE server to
provision each node using the Glance disk images provided by Instack. These disk images
include all the nessesary packages and configuration for an OPNFV deployment to execute.
Once the node's disk images have been written to disk the nodes will boot off the newly written
disks and execute cloud-init which will execute the final node configuration. This
configuration is largly completed by executing a puppet apply on each node.

Installation High-Level Overview - VM Deployment
================================================

The VM nodes deployment operates almost the same way as the bare metal deployment with a
few differences.  ``opnfv-deploy`` still deploys an Instack VM. In addition to the Instack VM
a collection of VMs (3 control nodes + 2 compute for an HA deployment or 1 control node and
1 compute node for a Non-HA Deployment) will be defined for the target OPNFV deployment.
The part of the toolchain that executes IPMI power instructions calls into libvirt instead of
the IPMI interfaces on baremetal servers to operate the power managment.  These VMs are then
provisioned with the same disk images and configuration that baremetal would be.

To RDO Manager these nodes look like they have just built and registered the same way as
bare metal nodes, the main difference is the use of a libvirt driver for the power management.

Installation Guide - Bare Metal Deployment
==========================================

**WARNING: Baremetal documentation is not complete.  WARNING: The main missing instructions are r elated to bridging
the networking for the undercloud to the physical underlay network for the overcloud to be deployed to.**

This section goes step-by-step on how to correctly install and provision the OPNFV target
system to bare metal nodes.

Install Bare Metal Jumphost
---------------------------

1.  If your Jumphost does not have CentOS 7 already on it, or you would like to do a fresh
    install, then download the Apex bootable ISO <http://artifacts.opnfv.org/> here.

2.  Boot the ISO off of a USB or other installation media and walk through installing OPNFV CentOS 7.
    The ISO comes prepare to be written directy to a USB drive with dd as such:

    ``dd if=opnfv-apex.iso of=/dev/sdX bs=4M``

    Replace /dev/sdX with the device assigned to your usb drive. Then select the USB device as the
    boot media on your Jumphost

3.  After OS is installed login to your Jumphost as root.

4.  Configure IP addresses on the interfaces that you have selected as your networks.

5.  Configure the IP gateway to the Internet either, preferably on the public interface.

6.  Configure your ``/etc/resolv.conf`` to point to a DNS server (8.8.8.8 is provided by Google).

Creating a Node Inventory File
------------------------------

IPMI configuration information gathered in section `Execution Requirements (Bare Metal Only)`_ needs to be added to the ``instackenv.json`` file.

1.  Make a copy of ``/var/opt/opnfv/instackenv.json.example`` into root's home directory: ``/root/instackenv.json``

2.  Edit the file in your favorite editor.

3.  The nodes dictionary contains a definition block for each baremetal host that will be deployed.  1 or more compute nodes and 3 controller nodes are required. (The example file contains blocks for each of these already).  It is optional at this point to add more compute nodes into the dictionary.

4.  Edit the following values for each node:

    - ``pm_type``: Power Management driver to use for the node
    - ``pm_addr``: IPMI IP Address
    - ``pm_user``: IPMI username
    - ``pm_password``: IPMI password

5.  Save your changes.

Creating a Network Environment File
-----------------------------------

Network environment information gathered in section `Network Requirements`_ needs to be added to the ``network-environment.yaml`` file.

1. Make a copy of ``/var/opt/opnfv/network-environment.yaml`` into root's home directory: ``/root/network-environment.yaml``

2.  Edit the file in your favorite editor.

3. Update the information (TODO: More Cowbell please!)

Running ``opnfv-deploy``
------------------------

You are now ready to deploy OPNFV!  ``opnfv-deploy`` will use the instackenv.json and network-environment.yaml to deploy OPNFV.
The names of these files are important.  ``opnfv-deploy`` will look for ``instackenv.json`` and
``network-environment.yaml`` in the present working directory when it is run.

Follow the steps below to execute:

1.  Ensure that you present working directory includes both the ``instackenv.json`` and ``network-environment.yaml`` files.

2.  execute ``opnfv-deploy``

3.  It will take about approximately 30 minutes to stand up instack, configure the deployment and execute the deployment.  If something goes wrong during this part of the process, it is most likely a problem with the setup of your network or the information in your configuration files.  You will also notice different outputs in your shell.

4.  The message "Overcloud Deployed" will display when When the deployment is complete.  Just above this message there
    will be a URL that ends in port http://<host>:5000. This url is also the endpoint for the OPNFV Horizon Dashboard
    if connected to on port 80.

Verifying the Setup
-------------------

Once the deployment has finished, the OPNFV deployment can be accessed via the Instack node. From 
the jump host ssh to the instack host and become the stack user. Alternativly ssh keys have been
setup such that the root user on the jump host can ssh to Instack directly as the stack user.

| ``ssh root@192.0.2.1``
| ``su - stack``

Once connected to Instack as the stack user look for two keystone files that can be used to
interact with the undercloud and the overcloud. Source the appropriate to interact with the
respective OpenStack deployment.

| ``source stackrc`` (undercloud / Instack)
| ``source overcloudrc`` (overcloud / OPNFV)

The contents of these files include the credentials for the administrative user for Instack and
OPNFV respectivly. At this point both Instack and OPNFV can be interacted with just as any
OpenStack installation can be. Start by listing the nodes in the undercloud that were used
to deploy the overcloud.

| ``source stackrc``
| ``openstack server list``

The control and compute nodes will be listed in the output of this server list command. The IP
addresses that are listed are the control plane addresses that were used to provision the nodes.
Use these IP addresses to connect to these nodes. Initial authenticaiton requires using the
user heat-admin.

| ``ssh heat-admin@192.0.2.7``

To begin creating users, images, networks, servers, etc in OPNFV source the overcloudrc file or
retrieve the admin user's credentials from the overcloudrc file and connect to the web Dashboard.


You are now able to follow the `OpenStack Verification`_ section.

OpenStack Verification
----------------------

Once connected to the OPNFV Dashboard make sure the OPNFV target system is working correctly:

1.  In the left pane, click Compute -> Images, click Create Image.

2.  Insert a name "cirros", Insert an Image Location ``http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img``.

3.  Select format "QCOW2", select Public, then click Create Image.

4.  Now click Project -> Network -> Networks, click Create Network.

5.  Enter a name "internal", click Next.

6.  Enter a subnet name "internal_subnet", and enter Network Address ``172.16.1.0/24``, click Next.

7. Now go to Project -> Compute -> Instances, click Launch Instance.

8. Enter Instance Name "first_instance", select Instance Boot Source "Boot from image", and then select Image Name "cirros".

9. Click Launch, status will cycle though a couple states before becoming "Active".

10. Steps 7 though 9 can be repeated to launch more instances.

11. Once an instance becomes "Active" their IP addresses will display on the Instances page.
  
12. Click the name of an instance, then the "Console" tab and login as "cirros"/"cubswin:)"

13. To verify storage is working, click Project -> Compute -> Volumes, Create Volume

14. Give the volume a name and a size of 1 GB

15. Once the volume becomes "Available" click the dropdown arrow and attach it to an instance.

Congratulations you have successfully installed OPNFV!

Installation Guide - VM Deployment
==================================

This section goes step-by-step on how to correctly install and provision the OPNFV target system to VM nodes.

Install Jumphost
----------------

Follow the instructions in the `Install Bare Metal Jumphost`_ section.

Running ``opnfv-deploy``
------------------------

You are now ready to deploy OPNFV!  ``opnfv-deploy`` has virtual deployment capability that includes all of the configuration nessesary to deploy OPNFV with no modifications.

If no modifications are made to the included configurations the target environment will deploy with the following architecture:

    - 1 Instack VM

    - The option of 3 control and 2 compute VMs (HA Deploy / default) or 1 control and 1 compute VM (Non-HA deploy / pass -n)

    - 2 networks, one for provisioning, internal API, storage and tenant networking traffic and a second for the external network

Follow the steps below to execute:

1.  ``opnfv-deploy --virtual [ --no-ha ]``

2.  It will take approximately 30 minutes to stand up instack, define the target virtual machines, configure the deployment and execute the deployment.  You will notice different outputs in your shell.
    
3.  When the deployment is complete you will see "Overcloud Deployed"

Verifying the Setup - VMs
-------------------------

To verify the set you can follow the instructions in the `Verifying the Setup`_ section.

Before you get started following these instructions you will need to add IP addresses on the networks that have been
created for the External and provisioning networks. By default the External network is 192.168.37.0/24 and the
provisioning network is 192.0.2.0/24. To access these networks simply add an IP to brbm and brbm1 and set their link to
up. This will provide a route from the hypervisor into the virtual networks acting as OpenStack's underlay network in
the virtual deployment.

| ``ip addr add 192.0.2.252/24 dev brbm``
| ``ip link set up dev brbm``
| ``ip addr add 192.168.37.252/24 dev brbm1``
| ``ip link set up dev brbm1``

Once these IP addresses are assigned and the links are up the gateways on the overcloud's networks should be pingable
and read to be SSHed to.

| ``ping 192.0.2.1``
| ``ping 192.168.37.1``

Now conitinue with the `Verifying the Setup`_ section.

OpenStack Verification - VMs
----------------------------

Follow the steps in `OpenStack Verification`_ section.

Frequently Asked Questions
==========================

License
=======

All Apex and "common" entities are protected by the `Apache 2.0 License <http://www.apache.org/licenses/>`_.

References
==========

OPNFV
-----

`OPNFV Home Page <www.opnfv.org>`_

`OPNFV Genesis project page <https://wiki.opnfv.org/get_started>`_

OpenStack
---------

`OpenStack Juno Release artifacts <http://www.openstack.org/software/juno>`_

`OpenStack documentation <http://docs.openstack.org>`_

OpenDaylight
------------

Upstream OpenDaylight provides `a number of packaging and deployment options <https://wiki.opendaylight.org/view/Deployment>`_ meant for consumption by downstream projects like OPNFV.

Currently, OPNFV Foreman uses `OpenDaylight's Puppet module <https://github.com/dfarrell07/puppet-opendaylight>`_, which in turn depends on `OpenDaylight's RPM <https://copr.fedoraproject.org/coprs/dfarrell07/OpenDaylight/>`_.

Note that the RPM is currently hosted on Copr, but `will soon <https://trello.com/c/qseotfgL/171-host-odl-rpm-on-odl-infra>`_ be migrated to OpenDaylight's infrastructure and/or the new CentOS NFV SIG.

Foreman
-------

`Foreman documentation <http://theforeman.org/documentation.html>`_

:Authors: Tim Rozet (trozet@redhat.com)
:Authors: Dan Radez (dradez@redhat.com)
:Version: 1.0

**Documentation tracking**

Revision: _sha1_

Build date:  _date_

