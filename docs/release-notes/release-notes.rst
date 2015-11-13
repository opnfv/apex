=============================================================================================
OPNFV Release Notes for the Bramaputra release of OPNFV when using Apex as a deployment tool
=============================================================================================


.. contents:: Table of Contents
   :backlinks: none


Abstract
========

This document provides the release notes for Bramaputra release with the Apex deployment toolchain.

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
| 2015-09-10         | 0.2.0              | Tim Rozet          | Updated for SR1    |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2015-06-03         | 0.1.2              | Tim Rozet          | Minor Edits        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2015-06-02         | 0.1.1              | Chris Price        | Minor Edits        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2015-04-16         | 0.1.0              | Tim Rozet          | First draft        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+

Important notes
===============

This is the OPNFV Bramaputra release that implements the deploy stage of the OPNFV CI pipeline via Apex.

Apex is based on RDO Manager. More information at http://rdoproject.org

Carefully follow the installation-instructions which guide a user on how to deploy OPNFV using Apex installer.

Summary
=======

Bramaputra release with the Apex deployment toolchain will establish an OPNFV target system
on a Pharos compliant lab infrastructure.  The current definition of an OPNFV target system
is and OpenStack Liberty version combined with OpenDaylight version: Lithium.  The system
is deployed with OpenStack High Availability (HA) for most OpenStack services.  OpenDaylight
is deployed in non-HA form as HAi support is not availble for OpenDaylight at the time of
the Bramaputra release.  Ceph storage is used as Cinder backend, and is the only supported
storage for Bramaputra. Ceph is setup as 3 OSDs and 3 Monitors, one OSD+Mon per Controller
node.

- Documentation is built by Jenkins
- .iso image is built by Jenkins
- Jenkins deploys a Bramaputra release with the Apex deployment toolchain baremetal, which includes 3 control+network nodes, and 2 compute nodes.

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | apex                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | apex/bramaputra.2016.1.0             |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | arno.2016.1.0                        |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2015-02-??                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | OPNFV Bramaputra release             |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Version change
--------------

Module version changes
~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of the Bramapurta release with the Apex deployment toolchain.
It is based on following upstream versions:

- OpenStack (Liberty release)

- OpenDaylight Lithium

- CentOS 7

Document version changes
~~~~~~~~~~~~~~~~~~~~~~~~

This is the first tracked version of Bramaputra release with the Apex deployment toolchain.
The following documentation is provided with this release:

- OPNFV Installation instructions for the Bramaputra release with the Apex deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Bramaputra release with the Apex deployment toolchain - ver. 1.0.0 (this document)

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
|                                      | Documentation for Bramaputra         |
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
Instack qcow2 disk image
Overcloud glance disk images
- deploy-ramdisk-ironic.initramfs
- deploy-ramdisk-ironic.kernel
- discovery-ramdisk.initramfs
- discovery-ramdisk.kernel
- fedora-user.qcow2
- overcloud-full.initrd
- overcloud-full.qcow2
- overcloud-full.vmlinuz
build.sh - Builds the above artifacts
deploy.sh - Automatically deploys Target OPNFV System to Bare Metal

Documentation deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for the Bramaputra release with the Apex deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Bramaputra release with the Apex deployment toolchain - ver. 1.0.0 (this document)

Known Limitations, Issues and Workarounds
=========================================

System Limitations
------------------

**Max number of blades:**   1 Apex master, 3 Controllers, 20 Compute blades

**Min number of blades:**   1 Apex master, 1 Controller, 1 Compute blade

**Storage:**    Ceph is the only supported storage configuration.

**Min master requirements:** At least 2048 MB of RAM


Known issues
------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-31                        | Support installs without internet    |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Workarounds
-----------
**-**


Test Result
===========

The Bramaputra release with the Apex deployment toolchain has undergone QA test runs with the following results:

+--------------------------------------+--------------------------------------+
| **TEST-SUITE**                       | **Results:**                         |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **-**                                | **-**                                |
+--------------------------------------+--------------------------------------+


References
==========

For more information on the OPNFV Bramaputra release, please see:

http://wiki.opnfv.org/releases/bramaputra

:Authors: Tim Rozet (trozet@redhat.com)
:Authors: Dan Radez (dradez@redhat.com)
:Version: 1.0.0

**Documentation tracking**

Revision: _sha1_

Build date:  _date_

