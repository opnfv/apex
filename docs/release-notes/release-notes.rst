============================================================================================
OPNFV Release Notes for the Brahmaputra release of OPNFV when using Apex as a deployment tool
============================================================================================


.. contents:: Table of Contents
   :backlinks: none


Abstract
========

This document provides the release notes for Brahmaputra release with the Apex deployment toolchain.

License
=======

All Apex and "common" entities are protected by the Apache License ( http://www.apache.org/licenses/ )


Version history
===============


+--------------------+--------------------+--------------------+--------------------+
| **Date**           | **Ver.**           | **Author**         | **Comment**        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2015-09-17         | 1.0.0              | Dan Radez          | Rewritten for      |
|                    |                    |                    | RDO Manager update |
+--------------------+--------------------+--------------------+--------------------+

Important notes
===============

This is the OPNFV Brahmaputra release that implements the deploy stage of the OPNFV CI pipeline via Apex.

Apex is based on RDO Manager. More information at http://rdoproject.org

Carefully follow the installation-instructions which guide a user on how to deploy OPNFV using Apex installer.

Summary
=======

Brahmaputra release with the Apex deployment toolchain will establish an OPNFV target system
on a Pharos compliant lab infrastructure.  The current definition of an OPNFV target system
is and OpenStack Liberty combined with OpenDaylight Beryllium.  The system is deployed with
OpenStack High Availability (HA) for most OpenStack services.  OpenDaylight is deployed in
non-HA form as HA support is not availble for OpenDaylight at the time of the Brahmaputra
release.  Ceph storage is used as Cinder backend, and is the only supported storage for
Brahmaputra. Ceph is setup as 3 OSDs and 3 Monitors, one OSD+Mon per Controller node.

- Documentation is built by Jenkins
- .iso image is built by Jenkins
- .rpm packages are built by Jenkins
- Jenkins deploys a Brahmaputra release with the Apex deployment toolchain baremetal,
  which includes 3 control+network nodes, and 2 compute nodes.

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | apex                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | apex/brahmaputra.1.0                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | brahmaputra.1.0                      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2015-02-25                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | OPNFV Brahmaputra release            |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Version change
--------------

Module version changes
~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of the Brahmaputra release with the Apex deployment toolchain.
It is based on following upstream versions:

- OpenStack (Liberty release)

- OpenDaylight (Beryllium release)

- CentOS 7

Document version changes
~~~~~~~~~~~~~~~~~~~~~~~~

This is the first tracked version of Brahmaputra release with the Apex deployment toolchain.
The following documentation is provided with this release:

- OPNFV Installation instructions for the Brahmaputra release with the Apex deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Brahmaputra release with the Apex deployment toolchain - ver. 1.0.0 (this document)

Feature additions
~~~~~~~~~~~~~~~~~

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-32                        | Build.sh integration of RDO Manager  |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-6                         | Deploy.sh integration of RDO Manager |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-34                        | Migrate and update Release           |
|                                      | Documentation for Brahmaputra        |
+--------------------------------------+--------------------------------------+

Bug corrections
~~~~~~~~~~~~~~~

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
|                                      |                                      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Deliverables
------------

Software deliverables
~~~~~~~~~~~~~~~~~~~~~
Apex .iso file
Apex overcloud .rpm (opnfv-apex)
Apex undercloud .rpm (opnfv-apex-undercloud)
Apex common .rpm (opnfv-apex-common)
build.sh - Builds the above artifacts
opnfv-deploy - Automatically deploys Target OPNFV System
opnfv-clean - Automatically resets a Target OPNFV Deployment

Documentation deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for the Brahmaputra release with the Apex deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Brahmaputra release with the Apex deployment toolchain - ver. 1.0.0 (this document)

Known Limitations, Issues and Workarounds
=========================================

System Limitations
------------------

**Max number of blades:**   1 Apex undercloud, 3 Controllers, 20 Compute blades

**Min number of blades:**   1 Apex undercloud, 1 Controller, 1 Compute blade

**Storage:**    Ceph is the only supported storage configuration.

**Min master requirements:** At least 16GB of RAM


Known issues
------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-89                        | Deploy Ceph OSDs on the compute      |
|                                      | nodes also                           |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-27                        | OpenContrail Support                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-30                        | Support for VLAN tagged network      |
|                                      | deployment architecture              |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-100                       | DNS1 and DNS2 not handled in         |
|                                      | nic bridging                         |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-47                        | Integrate Tacker as part of SFC      |
|                                      | Experimental Feature                 |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-84                        | --flat option no longer working      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-51                        | Integrate SDNVPN as a deploy option  |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-99                        | Syntax error when                    |
|                                      | running opnfv-deploy                 |
+--------------------------------------+--------------------------------------+

Workarounds
-----------
**-**


Test Result
===========

The Brahmaputra release with the Apex deployment toolchain has undergone QA test runs with the following results:

+--------------------------------------+--------------------------------------+
| **TEST-SUITE**                       | **Results:**                         |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **-**                                | **-**                                |
+--------------------------------------+--------------------------------------+


References
==========

For more information on the OPNFV Brahmaputra release, please see:

http://wiki.opnfv.org/releases/brahmaputra

:Authors: Tim Rozet (trozet@redhat.com)
:Authors: Dan Radez (dradez@redhat.com)
:Version: 1.0.0
