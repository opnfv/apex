========================================================================
OPNFV Release Notes for the Fraser release of OPNFV Apex deployment tool
========================================================================

Abstract
========

This document provides the release notes for Fraser release with the Apex
deployment toolchain.

License
=======

All Apex and "common" entities are protected by the Apache 2.0 License
( http://www.apache.org/licenses/ )

Important Notes
===============

This is the OPNFV Fraser release that implements the deploy stage of the
OPNFV CI pipeline via Apex.

Apex is based on RDO's Triple-O installation tool chain.
More information at http://rdoproject.org

Carefully follow the installation-instructions which guide a user on how to
deploy OPNFV using Apex installer.

Summary
=======

Fraser release with the Apex deployment toolchain will establish an OPNFV
target system on a Pharos compliant lab infrastructure.  The current definition
of an OPNFV target system is OpenStack Pike combined with an SDN
controller, such as OpenDaylight.  The system is deployed with OpenStack High
Availability (HA) for most OpenStack services.  SDN controllers are deployed
on every controller unless deploying with one the HA FD.IO scenarios.  Ceph
storage is used as Cinder backend, and is the only supported storage for
Fraser.  Ceph is setup as 3 OSDs and 3 Monitors, one OSD+Mon per Controller
node in an HA setup.  Apex also supports non-HA deployments, which deploys a
single controller and n number of compute nodes.  Furthermore, Apex is
capable of deploying scenarios in a bare metal or virtual fashion.  Virtual
deployments use multiple VMs on the Jump Host and internal networking to
simulate the a bare metal deployment.

- Documentation is built by Jenkins
- .iso image is built by Jenkins
- .rpm packages are built by Jenkins
- Jenkins deploys a Fraser release with the Apex deployment toolchain
  bare metal, which includes 3 control+network nodes, and 2 compute nodes.

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | apex                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | opnfv-6.1.0                          |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | 6.1.0                                |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2018-05-25                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | OPNFV Fraser release                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Version change
--------------

Module version changes
~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of the Fraser release with the Apex
deployment toolchain.  It is based on following upstream versions:

- OpenStack (Pike release)

- OpenDaylight (Nitrogen/Oxygen releases)

- CentOS 7

Document Version Changes
~~~~~~~~~~~~~~~~~~~~~~~~

This is the first tracked version of Fraser release with the Apex
deployment toolchain.
The following documentation is provided with this release:

- OPNFV Installation instructions for the Fraser release with the Apex
  deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Fraser release with the Apex deployment
  toolchain - ver. 1.0.0 (this document)

Deliverables
------------

Software Deliverables
~~~~~~~~~~~~~~~~~~~~~
- Apex .iso file
- Apex release .rpm (opnfv-apex-release)
- Apex overcloud .rpm (opnfv-apex) - For nosdn and OpenDaylight Scenarios
- Apex undercloud .rpm (opnfv-apex-undercloud)
- Apex common .rpm (opnfv-apex-common)
- build.py - Builds the above artifacts
- opnfv-deploy - Automatically deploys Target OPNFV System
- opnfv-clean - Automatically resets a Target OPNFV Deployment
- opnfv-util - Utility to connect to or debug Overcloud nodes + OpenDaylight

Documentation Deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for the Fraser release with the Apex
  deployment toolchain - ver. 6.1
- OPNFV Release Notes for the Fraser release with the Apex deployment
  toolchain - ver. 6.1 (this document)

Known Limitations, Issues and Workarounds
=========================================

System Limitations
------------------

**Max number of blades:**   1 Apex undercloud, 3 Controllers, 20 Compute blades

**Min number of blades:**   1 Apex undercloud, 1 Controller, 1 Compute blade

**Storage:**    Ceph is the only supported storage configuration.

**Min master requirements:** At least 16GB of RAM for baremetal Jump Host,
24GB for virtual deployments (noHA).


Known Issues
------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-280                       | Deleted network not cleaned up       |
|                                      | on controller                        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-295                       | Missing support for VLAN tenant      |
|                                      | networks                             |
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
| JIRA: APEX-412                       | Install failures with UEFI           |
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

For more information on the OPNFV Fraser release, please see:

http://wiki.opnfv.org/releases/Fraser

:Authors: Tim Rozet (trozet@redhat.com)
:Authors: Dan Radez (dradez@redhat.com)
:Version: 6.1
