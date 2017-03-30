========================================================================
OPNFV Release Notes for the Danube release of OPNFV Apex deployment tool
========================================================================


.. contents:: Table of Contents
   :backlinks: none


Abstract
========

This document provides the release notes for Danube release with the Apex
deployment toolchain.

License
=======

All Apex and "common" entities are protected by the Apache License
( http://www.apache.org/licenses/ )


Version History
===============


+-------------+-----------+-----------------+----------------------+
| **Date**    | **Ver.**  | **Authors**     | **Comment**          |
|             |           |                 |                      |
+-------------+-----------+-----------------+----------------------+
| 2017-03-30  | 4.0       | Tim Rozet       | Updates for Danube   |
+-------------+-----------+-----------------+----------------------+
| 2016-09-20  | 2.1.0     | Tim Rozet       | More updates for     |
|             |           |                 | Colorado             |
+-------------+-----------+-----------------+----------------------+
| 2016-08-11  | 2.0.0     | Dan Radez       | Updates for Colorado |
+-------------+-----------+-----------------+----------------------+
| 2015-09-17  | 1.0.0     | Dan Radez       | Rewritten for        |
|             |           |                 | RDO Manager update   |
+-------------+-----------+-----------------+----------------------+

Important Notes
===============

This is the OPNFV Danube release that implements the deploy stage of the
OPNFV CI pipeline via Apex.

Apex is based on RDO's Triple-O installation tool chain.
More information at http://rdoproject.org

Carefully follow the installation-instructions which guide a user on how to
deploy OPNFV using Apex installer.

Summary
=======

Danube release with the Apex deployment toolchain will establish an OPNFV
target system on a Pharos compliant lab infrastructure.  The current definition
of an OPNFV target system is OpenStack Newton combined with an SDN
controller, such as OpenDaylight.  The system is deployed with OpenStack High
Availability (HA) for most OpenStack services.  SDN controllers are deployed
on every controller unless deploying with one the HA FD.IO scenarios.  Ceph
storage is used as Cinder backend, and is the only supported storage for
Danube.  Ceph is setup as 3 OSDs and 3 Monitors, one OSD+Mon per Controller
node in an HA setup.  Apex also supports non-HA deployments, which deploys a
single controller and n number of compute nodes.  Furthermore, Apex is
capable of deploying scenarios in a bare metal or virtual fashion.  Virtual
deployments use multiple VMs on the jump host and internal networking to
simulate the a bare metal deployment.

- Documentation is built by Jenkins
- .iso image is built by Jenkins
- .rpm packages are built by Jenkins
- Jenkins deploys a Danube release with the Apex deployment toolchain
  bare metal, which includes 3 control+network nodes, and 2 compute nodes.

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | apex                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | apex/danube.1.0                      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | danube.1.0                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2017-03-31                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | OPNFV Danube release                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Version change
--------------

Module version changes
~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of the Danube release with the Apex
deployment toolchain.  It is based on following upstream versions:

- OpenStack (Newton release)

- OpenDaylight (Boron/Carbon releases)

- CentOS 7

Document Version Changes
~~~~~~~~~~~~~~~~~~~~~~~~

This is the first tracked version of Danube release with the Apex
deployment toolchain.
The following documentation is provided with this release:

- OPNFV Installation instructions for the Danube release with the Apex
  deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Danube release with the Apex deployment
  toolchain - ver. 1.0.0 (this document)

Feature Additions
~~~~~~~~~~~~~~~~~

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-129                       | Adds OVN SDN Controller support      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-299                       | Migrate to OpenStack Newton          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-150                       | Allow for multiple external networks |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-301                       | Support Networking ODL v2 Driver     |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-300                       | Support OpenDaylight new netvirt     |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-302                       | Upstream Tacker and Congress         |
|                                      | support                              |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-106                       | Enable CPU pinning for Overcloud     |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-390                       | OpenDaylight HA as default for HA    |
|                                      | scenarios                            |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-357                       | Include Quagga in SDNVPN scenario    |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-262                       | Migrate to new network settings      |
|                                      | format                               |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-128                       | Adds Real Time KVM support           |
+--------------------------------------+--------------------------------------+

Bug Corrections
~~~~~~~~~~~~~~~

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-208                       | Need ability to specify which nic    |
|                                      | to place vlan on                     |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-215                       | Keystone services not configured and |
|                                      | error is silently ignored on VLAN    |
|                                      | Deployments                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-221                       | NoHA virtual deployments should use 1|
|                                      | compute                              |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-276                       | ODL HA is unstable and crashes       |
|                                      | frequently                           |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-287                       | Name mismatch for package openstack- |
|                                      | congress during overcloud build      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-339                       | Enable pinning for OVS DPDK          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-345                       | Horizon and cloud failures due to    |
|                                      | running out of file descriptors for  |
|                                      | MariaDB in noha deployments          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-370                       | ISO builds fail in Danube            |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-372                       | Specifying same NIC for storage and  |
|                                      | private network but different VLANs  |
|                                      | results in duplicate NIC error       |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-373                       | Running smoke tests should install   |
|                                      | Ansible onto jump host               |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-374                       | Ceph accidentally disabled by default|
+--------------------------------------+--------------------------------------+
| JIRA: APEX-378                       | OVS 2.5.90 NSH build fails           |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-382                       | yum update on undercloud breaks      |
|                                      | deployments                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-386                       | Fix os-net-config to match upstream  |
|                                      | stable/newton                        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-398                       | Tacker uses "RegionOne" instead of   |
|                                      | "regionOne"                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-399                       | hugepages are not enabled when       |
|                                      | configured in deploy settings        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-403                       | Remove Quagga from build process and |
|                                      | cache to artifacts                   |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-406                       | ODL FDIO neutron patches to all      |
|                                      | scenarios                            |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-408                       | Quagga's bgpd cannot start due to    |
|                                      | permissions                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-421                       | Update odl/hc/vpp versions for odl_l3|
|                                      | noha                                 |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-426                       | Missing virtual-computes arg in help |
|                                      | output for deploy                    |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-427                       | Neutron openvswitch agent starts when|
|                                      | openvswitch is restarted             |
+--------------------------------------+--------------------------------------+

Deliverables
------------

Software Deliverables
~~~~~~~~~~~~~~~~~~~~~
- Apex .iso file
- Apex release .rpm (opnfv-apex-release)
- Apex overcloud .rpm (opnfv-apex) - For nosdn and OpenDaylight Scenarios
- Apex undercloud .rpm (opnfv-apex-undercloud)
- Apex common .rpm (opnfv-apex-common)
- build.sh - Builds the above artifacts
- opnfv-deploy - Automatically deploys Target OPNFV System
- opnfv-clean - Automatically resets a Target OPNFV Deployment
- opnfv-util - Utility to connect to or debug Overcloud nodes + OpenDaylight

Documentation Deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for the Danube release with the Apex
  deployment toolchain - ver. 4.0
- OPNFV Release Notes for the Danube release with the Apex deployment
  toolchain - ver. 4.0 (this document)

Known Limitations, Issues and Workarounds
=========================================

System Limitations
------------------

**Max number of blades:**   1 Apex undercloud, 3 Controllers, 20 Compute blades

**Min number of blades:**   1 Apex undercloud, 1 Controller, 1 Compute blade

**Storage:**    Ceph is the only supported storage configuration.

**Min master requirements:** At least 16GB of RAM for baremetal jumphost,
24GB for virtual deployments (noHA).


Known Issues
------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-138                       | Unclear error message when interface |
|                                      | set to dhcp                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-280                       | Deleted network not cleaned up       |
|                                      | on controller                        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-295                       | Missing support for VLAN tenant      |
|                                      | networks                             |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-352                       | Package "openstack-utils" is         |
|                                      | missing from overcloud               |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-368                       | Ceilometer stores samples and events |
|                                      | forever                              |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-371                       | Ceph partitions need to be prepared  |
|                                      | on deployment when using 2nd disk    |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-375                       | Default glance storage points to     |
|                                      | http,swift when ceph disabled        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-389                       | Compute kernel parameters are used   |
|                                      | for all nodes                        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-410                       | Need to limit number of workers per  |
|                                      | OpenStack service for baremetal      |
|                                      | deployments                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-412                       | Install failures with UEFI           |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-417                       | Missing OVS 2.6 + NSH support        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-419                       | opnfv-clean sometimes leaves admin   |
|                                      | and public network down              |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-425                       | Need to tweak performance settings   |
|                                      | virtual DPDK scenarios               |
+--------------------------------------+--------------------------------------+


Workarounds
-----------
**-**


Test Result
===========

Please reference Functest project documentation for test results with the
Apex installer.


References
==========

For more information on the OPNFV Danube release, please see:

http://wiki.opnfv.org/releases/Danube

:Authors: Tim Rozet (trozet@redhat.com)
:Authors: Dan Radez (dradez@redhat.com)
:Version: 4.0
