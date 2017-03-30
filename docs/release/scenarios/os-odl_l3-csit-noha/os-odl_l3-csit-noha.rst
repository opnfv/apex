.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Danube 1.0 of
deployment with the OpenDaylight SDN controller and only CSIT relevant
features enabled.

.. contents::
   :depth: 3
   :local:

============
Introduction
============

This scenario is used primarily to validate and deploy a minimum Newton
OpenStack + OpenDaylight deployment with only required OpenStack services.

Scenario components and composition
===================================

This scenario is composed of only required OpenStack services enabled by
default, including Nova, Neutron, Glance, and Keystone. OpenDaylight is also
enabled.  File storage is used as the backend to Glance.

The purpose of this file is to deploy a minimum OpenStack setup that will
still be able to exercise OpenDaylight.  The use case for this scenario is
to be able to test OpenDaylight quickly in an environment with low
CPU/Memory requirements.


Scenario usage overview
=======================

Simply deploy this scenario by using the os-odl_l3-csit-noha.yaml deploy
settings file.

Limitations, Issues and Workarounds
===================================

* `APEX-112 <https://jira.opnfv.org/browse/APEX-112>`_:
   ODL routes local subnet traffic to GW
* `APEX-149 <https://jira.opnfv.org/browse/APEX-149>`_:
   OpenFlow rules are populated very slowly
* `APEX-268 <https://jira.opnfv.org/browse/APEX-268>`_:
   VMs with multiple floating IPs can only access via first NIC
* `APEX-384 <https://jira.opnfv.org/browse/APEX-384>`_:
   Not including odl_version in deploy settings causes error
* `APEX-422 <https://jira.opnfv.org/browse/APEX-422>`_:
   First nova instance DHCP request fails

References
==========

For more information on the OPNFV Danube release, please visit
http://www.opnfv.org/danube

