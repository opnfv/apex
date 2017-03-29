==========================================================================
OPNFV Release Notes for the Colorado release of OPNFV Apex deployment tool
==========================================================================


.. contents:: Table of Contents
   :backlinks: none


Abstract
========

This document provides the release notes for Colorado release with the Apex
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

This is the OPNFV Colorado release that implements the deploy stage of the
OPNFV CI pipeline via Apex.

Apex is based on RDO's Triple-O installation tool chain.
More information at http://rdoproject.org

Carefully follow the installation-instructions which guide a user on how to
deploy OPNFV using Apex installer.

Summary
=======

Colorado release with the Apex deployment toolchain will establish an OPNFV
target system on a Pharos compliant lab infrastructure.  The current definition
of an OPNFV target system is OpenStack Mitaka combined with an SDN
controller, such as OpenDaylight.  The system is deployed with OpenStack High
Availability (HA) for most OpenStack services.  SDN controllers are deployed
only on the first controller (see HAIssues_ for known HA SDN issues).  Ceph
storage is used as Cinder backend, and is the only supported storage for
Colorado. Ceph is setup as 3 OSDs and 3 Monitors, one OSD+Mon per Controller
node in an HA setup.  Apex also supports non-HA deployments, which deploys a
single controller and n number of compute nodes.  Furthermore, Apex is
capable of deploying scenarios in a bare metal or virtual fashion.  Virtual
deployments use multiple VMs on the jump host and internal networking to
simulate the a bare metal deployment.

- Documentation is built by Jenkins
- .iso image is built by Jenkins
- .rpm packages are built by Jenkins
- Jenkins deploys a Colorado release with the Apex deployment toolchain
  bare metal, which includes 3 control+network nodes, and 2 compute nodes.

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | apex                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | apex/colorado.1.0                    |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | colorado.1.0                         |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2016-09-22                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | OPNFV Colorado release               |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Version change
--------------

Module version changes
~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of the Colorado release with the Apex
deployment toolchain.  It is based on following upstream versions:

- OpenStack (Mitaka release)

- OpenDaylight (Beryllium/Boron releases)

- CentOS 7

Document Version Changes
~~~~~~~~~~~~~~~~~~~~~~~~

This is the first tracked version of Colorado release with the Apex
deployment toolchain.
The following documentation is provided with this release:

- OPNFV Installation instructions for the Colorado release with the Apex
  deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Colorado release with the Apex deployment
  toolchain - ver. 1.0.0 (this document)

Feature Additions
~~~~~~~~~~~~~~~~~

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-107                       | OpenDaylight HA - OVSDB Clustering   |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-108                       | Migrate to OpenStack Mitaka          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-30                        | Support VLAN tagged deployments      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-105                       | Enable Huge Page Configuration       |
|                                      | Options                              |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-111                       | Allow RAM to be specified for        |
|                                      | Control/Compute in Virtual           |
|                                      | Deployments                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-119                       | Enable OVS DPDK as a deployment      |
|                                      | Scenario in Apex                     |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-126                       | Tacker Service deployed by Apex      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-135                       | Congress Service deployed by Apex    |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-127                       | Nova Instance CPU Pinning            |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-130                       | IPv6 Underlay Deployment             |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-133                       | FDIO with Honeycomb Agent            |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-141                       | Integrate VSPERF into Apex           |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-172                       | Enable ONOS SFC                      |
+--------------------------------------+--------------------------------------+

Bug Corrections
~~~~~~~~~~~~~~~

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-86                        | Need ability to specify number of    |
|                                      | compute nodes                        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-180                       | Baremetal deployment error: Failed to|
|                                      | mount root partition /dev/sda on     |
|                                      | /mnt/rootfs                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-161                       | Heat autoscaling stack creation fails|
|                                      | for non-admin users                  |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-198                       | Missing NAT iptables rule for public |
|                                      | network in instack VM                |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-147                       | Installer doesn't generate/distribute|
|                                      | SSH keys between compute nodes       |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-109                       | ONOS routes local subnet traffic to  |
|                                      | GW                                   |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-146                       | Swift service present in available   |
|                                      | endpoints                            |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-160                       | Enable force_metadata to support     |
|                                      | subnets with VM as the router        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-114                       | OpenDaylight GUI is not available    |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-100                       | DNS1 and DNS2 should be handled in   |
|                                      | nic bridging                         |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-100                       | DNS1 and DNS2 should be handled in   |
|                                      | nic bridging                         |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-155                       | NIC Metric value not used when       |
|                                      | bridging NICs                        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-136                       | 2 network deployment fails           |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-89                        | Deploy Ceph OSDs on compute nodes    |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-137                       | added arping ass dependency for      |
|                                      | ONOS deployments                     |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-121                       | VM Storage deletion intermittently   |
|                                      | fails                                |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-182                       | Nova services not correctly deployed |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-153                       | brbm bridge not created in jumphost  |
+--------------------------------------+--------------------------------------+

Deliverables
------------

Software Deliverables
~~~~~~~~~~~~~~~~~~~~~
- Apex .iso file
- Apex release .rpm (opnfv-apex-release)
- Apex overcloud .rpm (opnfv-apex) - For nosdn and OpenDaylight Scenarios
- Apex overcloud onos .rpm (opnfv-apex-onos) - ONOS Scenarios
- Apex undercloud .rpm (opnfv-apex-undercloud)
- Apex common .rpm (opnfv-apex-common)
- build.sh - Builds the above artifacts
- opnfv-deploy - Automatically deploys Target OPNFV System
- opnfv-clean - Automatically resets a Target OPNFV Deployment
- opnfv-util - Utility to connect to or debug Overcloud nodes + OpenDaylight

Documentation Deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for the Colorado release with the Apex
  deployment toolchain - ver. 1.0.0
- OPNFV Release Notes for the Colorado release with the Apex deployment
  toolchain - ver. 1.0.0 (this document)

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
| JIRA: APEX-203                       | Swift proxy enabled and fails in noha|
|                                      | deployments                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-215                       | Keystone services not configured and |
|                                      | the error is silently ignored (VLAN  |
|                                      | Deployments)                         |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-208                       | Need ability to specify which NIC to |
|                                      | place VLAN on                        |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-254                       | Add dynamic hugepages configuration  |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-138                       | Unclear error message when interface |
|                                      | set to dhcp                          |
+--------------------------------------+--------------------------------------+
| JIRA: APEX-389 (Danube)              | Compute kernel parameters are used   |
|                                      | for all nodes                        |
+--------------------------------------+--------------------------------------+


Workarounds
-----------
**-**

Scenario specific release notes
===============================

Scenario os-odl_l3-nofeature known issues
-----------------------------------------

* `APEX-112 <https://jira.opnfv.org/browse/APEX-112>`_:
   ODL routes local subnet traffic to GW

Scenario os-odl_l2-nofeature known issues
-----------------------------------------

* `APEX-149 <https://jira.opnfv.org/browse/APEX-149>`_:
   Openflow rules are populated very slowly

Scenario os-odl-bgpvpn known issues
--------------------------------------

* `APEX-278 <https://jira.opnfv.org/browse/APEX-278>`_:
   Duplicate neutron config class declaration for SDNVPN

Scenario os-onos-nofeatures/os-onos-sfc known issues
----------------------------------------------------

* `APEX-281 <https://jira.opnfv.org/browse/APEX-281>`_:
   ONOS sometimes fails to provide addresses to instances

Scenario os-odl_l2-sfc-noha known issues
----------------------------------------

* `APEX-275 <https://jira.opnfv.org/browse/APEX-275>`_:
   Metadata fails in Boron

Scenario os-nosdn-ovs known issues
----------------------------------

* `APEX-274 <https://jira.opnfv.org/browse/APEX-274>`_:
   OVS DPDK scenario does not create vhost user ports

Scenario os-nosdn-fdio-noha known issues
----------------------------------------

* `FDS-156 <https://jira.opnfv.org/browse/FDS-156>`_:
  os-nosdn-fdio-noha scenario:
  Race conditions for network-vif-plugged notification
* `FDS-160 <https://jira.opnfv.org/browse/FDS-160>`_:
  os-nosdn-fdio-noha scenario: Vlan fix on controller
* `FDS-269 <https://jira.opnfv.org/browse/FDS-269>`_:
  os-nosdn-fdio-noha scenario/refstack_devcore failure -   tempest.api.volume.test_volumes_actions.
  VolumesV2ActionsTest.test_get_volume_attachment testcase
* `FDS-270 <https://jira.opnfv.org/browse/FDS-270>`_:
  os-nosdn-fdio-noha scenario/refstack_devcore failure -
  tearDownClass (tempest.api.volume.test_volumes_actions.
  VolumesV2ActionsTest)
* `FDS-271 <https://jira.opnfv.org/browse/FDS-271>`_:
  os-nosdn-fdio-noha scenario/snaps_smoke fails 1 test -
  VM not able to obtain IP from DHCP
* `FDS-272 <https://jira.opnfv.org/browse/FDS-272>`_:
  os-nosdn-fdio-noha scenario/domino fails because
  of https proxy issue

Scenario os-odl_l2-fdio-noha known issues
-----------------------------------------

* `FDS-264 <https://jira.opnfv.org/browse/FDS-264>`_:
  ODL sometimes creates vxlan on incorrect host
* `FDS-275 <https://jira.opnfv.org/browse/FDS-275>`_:
  Refstack testcase ImagesOneServerTestJSON.
  test_create_delete_image failure

Scenario os-odl_l2-fdio-ha known issues
---------------------------------------

* `FDS-264 <https://jira.opnfv.org/browse/FDS-264>`_:
  ODL sometimes creates vxlan on incorrect host
* `FDS-275 <https://jira.opnfv.org/browse/FDS-275>`_:
  Refstack testcase ImagesOneServerTestJSON.
  test_create_delete_image failure

Scenario os-odl_l3-fdio-noha known issues
-----------------------------------------

Note that a set of manual configration steps need to be performed
post an automated deployment for the scenario to be fully functional.
Please refer to `APEX-420 <https://jira.opnfv.org/browse/APEX-420>`_
for details.

* `FDS-246 <https://jira.opnfv.org/browse/FDS-246>`_:
  Metadata service not reachable via dhcp namespace
* `FDS-251 <https://jira.opnfv.org/browse/FDS-251>`_:
  Nat outbound interface is not set correctly in all cases
* `FDS-252 <https://jira.opnfv.org/browse/FDS-252>`_:
  VPP renderer config is sometimes resolved after
  hundreds of configuration changes
* `FDS-264 <https://jira.opnfv.org/browse/FDS-264>`_:
  ODL sometimes creates vxlan on incorrect host
* `FDS-275 <https://jira.opnfv.org/browse/FDS-275>`_:
  Refstack testcase ImagesOneServerTestJSON.
  test_create_delete_image failure
* `APEX-420 <https://jira.opnfv.org/browse/APEX-420>`_:
  Public and tenant interface configuration in odl for
  fdio_l3 noha scenario

.. _HAIssues:

General HA scenario known issues
--------------------------------

* `COPPER-22 <https://jira.opnfv.org/browse/COPPER-22>`_:
   Congress service HA deployment is not yet supported/verified.
* `APEX-276 <https://jira.opnfv.org/browse/APEX-276>`_:
   ODL HA unstable and crashes frequently

Test Result
===========

The Colorado release with the Apex deployment toolchain has undergone QA
test runs with the following results:

+--------------------------------------+--------------------------------------+
| **TEST-SUITE**                       | **Results:**                         |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **-**                                | **-**                                |
+--------------------------------------+--------------------------------------+


References
==========

For more information on the OPNFV Colorado release, please see:

http://wiki.opnfv.org/releases/Colorado

:Authors: Tim Rozet (trozet@redhat.com)
:Authors: Dan Radez (dradez@redhat.com)
:Version: 2.1.0
