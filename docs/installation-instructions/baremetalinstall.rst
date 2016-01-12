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

Introspection boots off of custom introspection PXE images. These images are designed to look
at the properties of the hardware that is booting off of them and report the properties of
it back to the Instack node.

After introspection Instack will execute a Heat Stack Deployment to being node provisioning
and configuration.  The nodes will reboot and PXE again off the Instack PXE server to
provision each node using the Glance disk images provided by Instack. These disk images
include all the necessary packages and configuration for an OPNFV deployment to execute.
Once the node's disk images have been written to disk the nodes will boot off the newly written
disks and execute cloud-init which will execute the final node configuration. This
configuration is largly completed by executing a puppet apply on each node.

Installation Guide - Bare Metal Deployment
==========================================

**WARNING: Baremetal documentation is not complete.  WARNING: The main missing instructions are r elated to bridging
the networking for the undercloud to the physical underlay network for the overcloud to be deployed to.**

This section goes step-by-step on how to correctly install and provision the OPNFV target
system to bare metal nodes.

Install Bare Metal Jumphost
---------------------------

1a. If your Jumphost does not have CentOS 7 already on it, or you would like to do a fresh
    install, then download the Apex bootable ISO from OPNFV artifacts <http://artifacts.opnfv.org/>.

1b. If your Jump host already has CentOS 7 with libvirt running on it then install the
    opnfv-apex RPM from OPNFV artifacts <http://artifacts.opnfv.org/>.

2a.  Boot the ISO off of a USB or other installation media and walk through installing OPNFV CentOS 7.
    The ISO comes prepared to be written directly to a USB drive with dd as such:

    ``dd if=opnfv-apex.iso of=/dev/sdX bs=4M``

    Replace /dev/sdX with the device assigned to your usb drive. Then select the USB device as the
    boot media on your Jumphost

2b. Install the RDO Release RPM and the opnfv-apex RPM:

    ``sudo yum install -y https://www.rdoproject.org/repos/rdo-release.rpm opnfv-apex-{version}.rpm``

    The RDO Project release repository is needed to install OpenVSwitch, which is a dependency of
    opnfv-apex. If you do not have external connectivity to use this repository you need to download
    the OpenVSwitch RPM from the RDO Project repositories and install it with the opnfv-apex RPM.

3.  After the operating system and the opnfv-apex RPM are installed, login to your Jumphost as root.

4.  Configure IP addresses on the interfaces that you have selected as your networks.

5.  Configure the IP gateway to the Internet either, preferably on the public interface.

6.  Configure your ``/etc/resolv.conf`` to point to a DNS server (8.8.8.8 is provided by Google).

Creating a Node Inventory File
------------------------------

IPMI configuration information gathered in section `Execution Requirements (Bare Metal Only)`_
needs to be added to the ``instackenv.json`` file.

1.  Make a copy of ``/var/opt/opnfv/instackenv.json.example`` into root's home directory: ``/root/instackenv.json``

2.  Edit the file in your favorite editor.

3.  The nodes dictionary contains a definition block for each baremetal host that will be deployed.
    1 or more compute nodes and 3 controller nodes are required.
    (The example file contains blocks for each of these already).
    It is optional at this point to add more compute nodes into the dictionary.

4.  Edit the following values for each node:

    - ``pm_type``: Power Management driver to use for the node
    - ``pm_addr``: IPMI IP Address
    - ``pm_user``: IPMI username
    - ``pm_password``: IPMI password
    - ``capabilities``: Intended node role (profile:control or profile:compute)
    - ``cpu``: CPU cores available
    - ``memory``: Memory available in Mib
    - ``disk``: Disk space available in Gb
    - ``arch``: System architecture
    - ``mac``: MAC of the interface that will PXE boot from Instack

5.  Save your changes.

Creating a Network Environment File
-----------------------------------

Network environment information gathered in section `Network Requirements`_
needs to be added to the ``network-environment.yaml`` file.

1. Make a copy of ``/var/opt/opnfv/network-environment.yaml`` into root's home
directory: ``/root/network-environment.yaml``

2. Edit the file in your favorite editor.

3. Update the information (TODO: More Cowbell please!)

Running ``opnfv-deploy``
------------------------

You are now ready to deploy OPNFV!
``opnfv-deploy`` will use the instackenv.json and network-environment.yaml to deploy OPNFV.
The names of these files are important.  ``opnfv-deploy`` will look for ``instackenv.json`` and
``network-environment.yaml`` in the present working directory when it is run.

Follow the steps below to execute:

1.  execute ``sudo opnfv-deploy -i /path/to/instackenv.json -n /path/to/network-environment.yaml``

2.  It will take about approximately 30 minutes to stand up instack,
    configure the deployment and execute the deployment.
    If something goes wrong during this part of the process,
    it is most likely a problem with the setup of your network or the information in your configuration files.
    You will also notice different outputs in your shell.

3.  The message "Overcloud Deployed" will display when When the deployment is complete.  Just above this message there
    will be a URL that ends in port http://<host>:5000. This url is also the endpoint for the OPNFV Horizon Dashboard
    if connected to on port 80.
