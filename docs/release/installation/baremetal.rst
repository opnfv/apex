Installation High-Level Overview - Bare Metal Deployment
========================================================

The setup presumes that you have 6 or more bare metal servers already setup
with network connectivity on at least 1 or more network interfaces for all
servers via a TOR switch or other network implementation.

The physical TOR switches are **not** automatically configured from the OPNFV
reference platform.  All the networks involved in the OPNFV infrastructure as
well as the provider networks and the private tenant VLANs needs to be manually
configured.

The Jump Host can be installed using the bootable ISO or by using the
(``opnfv-apex*.rpm``) RPMs and their dependencies.  The Jump Host should then
be configured with an IP gateway on its admin or public interface and
configured with a working DNS server.  The Jump Host should also have routable
access to the lights out network for the overcloud nodes.

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
images provided by the undercloud. These disk images include all the necessary
packages and configuration for an OPNFV deployment to execute. Once the disk
images have been written to node's disks the nodes will boot locally and
execute cloud-init which will execute the final node configuration. At this
point in the deployment, the Heat Stack will complete, and Mistral will
takeover the configuration of the nodes. Mistral handles calling Ansible which
will connect to each node, and begin configuration. This configuration includes
launching the desired OPNFV services as containers, and generating their
configuration files. These configuration is largely completed by executing a
puppet apply on each container to generate the config files, which are then
stored on the overcloud host and mounted into the service container at runtime.

Installation Guide - Bare Metal Deployment
==========================================

This section goes step-by-step on how to correctly install and provision the
OPNFV target system to bare metal nodes.

Install Bare Metal Jump Host
----------------------------

1a. If your Jump Host does not have CentOS 7 already on it, or you would like
    to do a fresh install, then download the CentOS 7 DVD and perform a
    "Virtualization Host" install.  If you perform a "Minimal Install" or
    install type other than "Virtualization Host" simply run
    ``sudo yum -y groupinstall "Virtualization Host"``
    ``chkconfig libvirtd on && reboot``
    to install virtualization support and enable libvirt on boot. If you use
    the CentOS 7 DVD proceed to step 1b once the CentOS 7 with
    "Virtualization Host" support is completed.

1b. Boot the ISO off of a USB or other installation media and walk through
    installing OPNFV CentOS 7.  The ISO comes prepared to be written directly
    to a USB drive with dd as such:

    ``dd if=opnfv-apex.iso of=/dev/sdX bs=4M``

    Replace /dev/sdX with the device assigned to your usb drive. Then select
    the USB device as the boot media on your Jump Host

2a. Install these repos:

    ``sudo yum install https://repos.fedorapeople.org/repos/openstack/openstack-queens/rdo-release-queens-1.noarch.rpm``
    ``sudo yum install epel-release``
    ``sudo curl -o /etc/yum.repos.d/opnfv-apex.repo http://artifacts.opnfv.org/apex/gambia/opnfv-apex.repo``

    The RDO Project release repository is needed to install OpenVSwitch, which
    is a dependency of opnfv-apex. If you do not have external connectivity to
    use this repository you need to download the OpenVSwitch RPM from the RDO
    Project repositories and install it with the opnfv-apex RPM.  The
    opnfv-apex repo hosts all of the Apex dependencies which will automatically
    be installed when installing RPMs, but will be pre-installed with the ISO.

2b. Download the first Apex RPMs from the OPNFV downloads page, under the
    TripleO RPMs ``https://www.opnfv.org/software/downloads``. The dependent
    RPMs will be automatically installed from the opnfv-apex repo in the
    previous step.
    The following RPMs are available for installation:

    - python34-opnfv-apex        - (reqed) OPNFV Apex Python package
    - python34-markupsafe        - (reqed) Dependency of python34-opnfv-apex **
    - python34-jinja2            - (reqed) Dependency of python34-opnfv-apex **
    - python3-ipmi               - (reqed) Dependency of python34-opnfv-apex **
    - python34-pbr               - (reqed) Dependency of python34-opnfv-apex **
    - python34-virtualbmc        - (reqed) Dependency of python34-opnfv-apex **
    - python34-iptables          - (reqed) Dependency of python34-opnfv-apex **
    - python34-cryptography      - (reqed) Dependency of python34-opnfv-apex **
    - python34-libvirt           - (reqed) Dependency of python34-opnfv-apex **

    ** These RPMs are not yet distributed by CentOS or EPEL.
    Apex has built these for distribution with Apex while CentOS and EPEL do
    not distribute them. Once they are carried in an upstream channel Apex will
    no longer carry them and they will not need special handling for
    installation.  You do not need to explicitly install these as they will be
    automatically installed by installing python34-opnfv-apex when the
    opnfv-apex.repo has been previously downloaded to ``/etc/yum.repos.d/``.

    Install the required RPM (replace <rpm> with the actual downloaded
    artifact):
    ``yum -y install <python34-opnfv-apex>``

3.  After the operating system and the opnfv-apex RPMs are installed, login to
    your Jump Host as root.

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
    that will be deployed. 0 or more compute nodes and 1 or 3 controller nodes
    are required (the example file contains blocks for each of these already).
    It is optional at this point to add more compute nodes into the node list.
    By specifying 0 compute nodes in the inventory file, the deployment will
    automatically deploy "all-in-one" nodes which means the compute will run
    along side the controller in a single overcloud node. Specifying 3 control
    nodes will result in a highly-available service model.

3.  Edit the following values for each node:

    - ``mac_address``: MAC of the interface that will PXE boot from undercloud
    - ``ipmi_ip``: IPMI IP Address
    - ``ipmi_user``: IPMI username
    - ``ipmi_password``: IPMI password
    - ``pm_type``: Power Management driver to use for the node
        values: pxe_ipmitool (tested) or pxe_wol (untested) or pxe_amt (untested)
    - ``cpus``: (Introspected*) CPU cores available
    - ``memory``: (Introspected*) Memory available in Mib
    - ``disk``: (Introspected*) Disk space available in Gb
    - ``disk_device``: (Opt***) Root disk device to use for installation
    - ``arch``: (Introspected*) System architecture
    - ``capabilities``: (Opt**) Node's role in deployment
        values: profile:control or profile:compute

    \* Introspection looks up the overcloud node's resources and overrides these
    value. You can leave default values and Apex will get the correct values when
    it runs introspection on the nodes.

    ** If capabilities profile is not specified then Apex will select node's roles
    in the OPNFV cluster in a non-deterministic fashion.

    \*** disk_device declares which hard disk to use as the root device for
    installation.  The format is a comma delimited list of devices, such as
    "sda,sdb,sdc".  The disk chosen will be the first device in the list which
    is found by introspection to exist on the system.  Currently, only a single
    definition is allowed for all nodes.  Therefore if multiple disk_device
    definitions occur within the inventory, only the last definition on a node
    will be used for all nodes.

Creating the Settings Files
---------------------------

Edit the 2 settings files in /etc/opnfv-apex/. These files have comments to
help you customize them.

1. deploy_settings.yaml
   This file includes basic configuration options deployment, and also documents
   all available options.
   Alternatively, there are pre-built deploy_settings files available in
   (``/etc/opnfv-apex/``). These files are named with the naming convention
   os-sdn_controller-enabled_feature-[no]ha.yaml. These files can be used in
   place of the (``/etc/opnfv-apex/deploy_settings.yaml``) file if one suites
   your deployment needs. If a pre-built deploy_settings file is chosen there
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
    ``sudo opnfv-deploy -n network_settings.yaml
    -i inventory.yaml -d deploy_settings.yaml``
    If you need more information about the options that can be passed to
    opnfv-deploy use ``opnfv-deploy --help``.  -n
    network_settings.yaml allows you to customize your networking topology.
    Note it can also be useful to run the command with the ``--debug``
    argument which will enable a root login on the overcloud nodes with
    password: 'opnfvapex'.  It is also useful in some cases to surround the
    deploy command with ``nohup``.  For example:
    ``nohup <deploy command> &``, will allow a deployment to continue even if
    ssh access to the Jump Host is lost during deployment.

2.  Wait while deployment is executed.
    If something goes wrong during this part of the process, start by reviewing
    your network or the information in your configuration files. It's not
    uncommon for something small to be overlooked or mis-typed.
    You will also notice outputs in your shell as the deployment progresses.

3.  When the deployment is complete the undercloud IP and overcloud dashboard
    url will be printed. OPNFV has now been deployed using Apex.

.. _`Execution Requirements (Bare Metal Only)`: requirements.html#execution-requirements-bare-metal-only
.. _`Network Requirements`: requirements.html#network-requirements
