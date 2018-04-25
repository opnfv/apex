Setup Requirements
==================

Jump Host Requirements
---------------------

The Jump Host requirements are outlined below:

1.     CentOS 7 (from ISO or self-installed).

2.     Root access.

3.     libvirt virtualization support.

4.     minimum 1 networks and maximum 5 networks, multiple NIC and/or VLAN
       combinations are supported.  This is virtualized for a VM deployment.

5.     The Fraser Apex RPMs and their dependencies.

6.     16 GB of RAM for a bare metal deployment, 64 GB of RAM for a Virtual
       Deployment.

Network Requirements
--------------------

Network requirements include:

1.     No DHCP or TFTP server running on networks used by OPNFV.

2.     1-5 separate networks with connectivity between Jump Host and nodes.

       -  Control Plane (Provisioning)

       -  Private Tenant-Networking Network*

       -  External Network*

       -  Storage Network*

       -  Internal API Network* (required for IPv6 \*\*)

3.     Lights out OOB network access from Jump Host with IPMI node enabled
       (bare metal deployment only).

4.     External network is a routable network from outside the cloud,
       deployment. The External network is where public internet access would
       reside if available.

\*These networks can be combined with each other or all combined on the
Control Plane network.

\*\*Internal API network, by default, is collapsed with provisioning in IPv4
deployments, this is not possible with the current lack of PXE boot
support and therefore the API network is required to be its own
network in an IPv6 deployment.

Bare Metal Node Requirements
----------------------------

Bare metal nodes require:

1.     IPMI enabled on OOB interface for power control.

2.     BIOS boot priority should be PXE first then local hard disk.

3.     BIOS PXE interface should include Control Plane network mentioned above.

Execution Requirements (Bare Metal Only)
----------------------------------------

In order to execute a deployment, one must gather the following information:

1.     IPMI IP addresses for the nodes.

2.     IPMI login information for the nodes (user/pass).

3.     MAC address of Control Plane / Provisioning interfaces of the overcloud
       nodes.
