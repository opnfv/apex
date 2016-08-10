Installation High-Level Overview - Bare Metal Deployment
========================================================

The setup presumes that you have 6 or more bare metal servers already setup
with network connectivity on at least 1 or more network interfaces for all
servers via a TOR switch or other network implementation.

The physical TOR switches are **not** automatically configured from the OPNFV
reference platform.  All the networks involved in the OPNFV infrastructure as
well as the provider networks and the private tenant VLANs needs to be manually
configured.

The Jumphost can be installed using the bootable ISO or by using the
(``opnfv-apex*.rpm``) RPMs and their dependencies.  The Jumphost should then be
configured with an IP gateway on its admin or public interface and configured
with a working DNS server.  The Jumphost should also have routable access
to the lights out network for the overcloud nodes.

``opnfv-deploy`` is then executed in order to deploy the undercloud VM and to
provision the overcloud nodes.  ``opnfv-deploy`` uses three configuration files
in order to know how to install and provision the OPNFV target system.
The information gathered under section
`Execution Requirements (Bare Metal Only)`_ is put into the YAML file
``/etc/opnfv-apex/inventory.yaml`` configuration file.  Deployment options are
put into the YAML file ``/etc/opnfv-apex/deploy_settings.yaml``.  Alternatively
there are pre-baked deploy_settings files available in ``/etc/opnfv-apex/``.
These files are named with the naming convention
os-sdn_controller-enabled_feature-[no]ha.yaml. These files can be used in place
of the ``/etc/opnfv-apex/deploy_settings.yaml`` file if one suites your
deployment needs.  Networking definitions gathered under section
`Network Requirements`_ are put into the YAML file
``/etc/opnfv-apex/network_settings.yaml``.  ``opnfv-deploy`` will boot the
undercloud VM and load the target deployment configuration into the
provisioning toolchain.  This information includes MAC address, IPMI,
Networking Environment and OPNFV deployment options.

Once configuration is loaded and the undercloud is configured it will then
reboot the overcloud nodes via IPMI.  The nodes should already be set to PXE
boot first off the admin interface.  The nodes will first PXE off of the
undercloud PXE server and go through a discovery/introspection process.

Introspection boots off of custom introspection PXE images. These images are
designed to look at the properties of the hardware that is being booted
and report the properties of it back to the undercloud node.

After introspection the undercloud will execute a Heat Stack Deployment to
continue node provisioning and configuration.  The nodes will reboot and PXE
from the undercloud PXE server again to provision each node using Glance disk
images provided by the undercloud.  These disk images include all the necessary
packages and configuration for an OPNFV deployment to execute.  Once the disk
images have been written to node's disks the nodes will boot locally and
execute cloud-init which will execute the final node configuration. This
configuration is largly completed by executing a puppet apply on each node.

Installation High-Level Overview - VM Deployment
================================================

The VM nodes deployment operates almost the same way as the bare metal
deployment with a few differences mainly related to power management.
``opnfv-deploy`` still deploys an undercloud VM. In addition to the undercloud
VM a collection of VMs (3 control nodes + 2 compute for an HA deployment or 1
control node and 1 or more compute nodes for a Non-HA Deployment) will be
defined for the target OPNFV deployment.  The part of the toolchain that
executes IPMI power instructions calls into libvirt instead of the IPMI
interfaces on baremetal servers to operate the power managment.  These VMs are
then provisioned with the same disk images and configuration that baremetal
would be.

To Triple-O these nodes look like they have just built and registered the same
way as bare metal nodes, the main difference is the use of a libvirt driver for
the power management.

Installation Guide - Bare Metal Deployment
==========================================

This section goes step-by-step on how to correctly install and provision the
OPNFV target system to bare metal nodes.

Install Bare Metal Jumphost
---------------------------

1a. If your Jumphost does not have CentOS 7 already on it, or you would like to
    do a fresh install, then download the Apex bootable ISO from the OPNFV
    artifacts site <http://artifacts.opnfv.org/apex.html>.  There have been
    isolated reports of problems with the ISO having trouble completing
    installation successfully. In the unexpected event the ISO does not work
    please workaround this by downloading the CentOS 7 DVD and performing a
    "Virtualization Host" install.  If you perform a "Minimal Install" or
    install type other than "Virtualization Host" simply run
    ``sudo yum groupinstall "Virtualization Host"``
    ``chkconfig libvirtd on && reboot``
    to install virtualzation support and enable libvirt on boot. If you use the
    CentOS 7 DVD proceed to step 1b once the CentOS 7 with "Virtualzation Host"
    support is completed.

1b. If your Jump host already has CentOS 7 with libvirt running on it then
    install the install the RDO Release RPM:

    ``sudo yum install -y https://www.rdoproject.org/repos/rdo-release.rpm``

    The RDO Project release repository is needed to install OpenVSwitch, which
    is a dependency of opnfv-apex. If you do not have external connectivity to
    use this repository you need to download the OpenVSwitch RPM from the RDO
    Project repositories and install it with the opnfv-apex RPM.

2a. Boot the ISO off of a USB or other installation media and walk through
    installing OPNFV CentOS 7.  The ISO comes prepared to be written directly
    to a USB drive with dd as such:

    ``dd if=opnfv-apex.iso of=/dev/sdX bs=4M``

    Replace /dev/sdX with the device assigned to your usb drive. Then select
    the USB device as the boot media on your Jumphost

2b. If your Jump host already has CentOS 7 with libvirt running on it then
    install the opnfv-apex RPMs from the OPNFV artifacts site
    <http://artifacts.opnfv.org/apex.html>. The following RPMS are available
    for installation:

    - opnfv-apex                  - OpenDaylight L2 / L3 and ONOS support *
    - opnfv-apex-onos             - ONOS support *
    - opnfv-apex-opendaylight-sfc - OpenDaylight SFC support *
    - opnfv-apex-undercloud       - (reqed) Undercloud Image
    - opnfv-apex-common           - (reqed) Supporting config files and scripts
    - python34-markupsafe         - (reqed) Dependency of opnfv-apex-common **
    - python3-jinja2              - (reqed) Dependency of opnfv-apex-common **

    \* One or more of these RPMs is required
    Only one of opnfv-apex, opnfv-apex-onos and opnfv-apex-opendaylight-sfc is
    required. It is safe to leave the unneeded SDN controller's RPMs
    uninstalled if you do not intend to use them.

    ** These RPMs are not yet distributed by CentOS or EPEL.
    Apex has built these for distribution with Apex while CentOS and EPEL do
    not distribute them. Once they are carried in an upstream channel Apex will
    no longer carry them and they will not need special handling for
    installation.

    To install these RPMs download them to the local disk on your CentOS 7
    install and pass the file names directly to yum:
    ``sudo yum install python34-markupsafe-<version>.rpm
    python3-jinja2-<version>.rpm``
    ``sudo yum install opnfv-apex-<version>.rpm
    opnfv-apex-undercloud-<version>.rpm opnfv-apex-common-<version>.rpm``


3.  After the operating system and the opnfv-apex RPMs are installed, login to
    your Jumphost as root.

4.  Configure IP addresses on the interfaces that you have selected as your
    networks.

5.  Configure the IP gateway to the Internet either, preferably on the public
    interface.

6.  Configure your ``/etc/resolv.conf`` to point to a DNS server
    (8.8.8.8 is provided by Google).

Creating a Node Inventory File
------------------------------

IPMI configuration information gathered in section
`Execution Requirements (Bare Metal Only)`_ needs to be added to the
``inventory.yaml`` file.

1.  Copy ``/usr/share/doc/opnfv/inventory.yaml.example`` as your inventory file
    template to ``/etc/opnfv-apex/inventory.yaml``.

2.  The nodes dictionary contains a definition block for each baremetal host
    that will be deployed.  1 or more compute nodes and 3 controller nodes are
    required.  (The example file contains blocks for each of these already).
    It is optional at this point to add more compute nodes into the node list.

3.  Edit the following values for each node:

    - ``mac_address``: MAC of the interface that will PXE boot from undercloud
    - ``ipmi_ip``: IPMI IP Address
    - ``ipmi_user``: IPMI username
    - ``ipmi_password``: IPMI password
    - ``pm_type``: Power Management driver to use for the node
    - ``cpus``: (Introspected*) CPU cores available
    - ``memory``: (Introspected*) Memory available in Mib
    - ``disk``: (Introspected*) Disk space available in Gb
    - ``arch``: (Introspected*) System architecture
    - ``capabilities``: (Opt**) Node role (profile:control or profile:compute)

\* *Introspection looks up the overcloud node's resources and overrides these
    value. You can leave default values and Apex will get the correct values when
    it runs introspection on the nodes.*

** *If capabilities profile is not specified then Apex will select node's roles
   in the OPNFV cluster in a non-deterministic fashion.*

Creating the Settings Files
---------------------------

Edit the 2 settings files in /etc/opnfv-apex/. These files have comments to
help you customize them.

1. deploy_settings.yaml
   This file includes basic configuration options deployment.
   Alternatively, there are pre-built deploy_settings files available in
   (``/etc/opnfv-apex/``). These files are named with the naming convention
   os-sdn_controller-enabled_feature-[no]ha.yaml. These files can be used in
   place of the (``/etc/opnfv-apex/deploy_settings.yaml``) file if one suites
   your deployment needs. If a pre-built deploy_settings file is choosen there
   is no need to customize (``/etc/opnfv-apex/deploy_settings.yaml``). The
   pre-built file can be used in place of the
   (``/etc/opnfv-apex/deploy_settings.yaml``) file.

2. network_settings.yaml
   This file provides Apex with the networking information that satisfies the
   prerequisite `Network Requirements`_. These are specific to your
   environment.

Running ``opnfv-deploy``
------------------------

You are now ready to deploy OPNFV using Apex!
``opnfv-deploy`` will use the inventory and settings files to deploy OPNFV.

Follow the steps below to execute:

1.  Execute opnfv-deploy
    ``sudo opnfv-deploy [ --flat ] -n network_settings.yaml
    -i inventory.yaml -d deploy_settings.yaml``
    If you need more information about the options that can be passed to
    opnfv-deploy use ``opnfv-deploy --help`` --flat collapses all networks to a
    single nic, only uses the admin network from the network settings file.  -n
    network_settings.yaml allows you to customize your networking topology.

2.  Wait while deployment is executed.
    If something goes wrong during this part of the process, start by reviewing
    your network or the information in your configuration files. It's not
    uncommon for something small to be overlooked or mis-typed.
    You will also notice outputs in your shell as the deployment progresses.

3.  When the deployment is complete the undercloud IP and ovecloud dashboard
    url will be printed. OPNFV has now been deployed using Apex.

.. _`Execution Requirements (Bare Metal Only)`: requirements.html#execution-requirements-bare-metal-only
.. _`Network Requirements`: requirements.html#network-requirements
