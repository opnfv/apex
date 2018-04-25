.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Fraser 1.0 of
deployment with the OpenDaylight SDN controller and no extra features enabled.

============
Introduction
============

This scenario is used primarily to validate and deploy a Pike OpenStack
deployment with OpenDaylight, and without any NFV features enabled.

Scenario components and composition
===================================

This scenario is composed of common OpenStack services enabled by default,
including Nova, Neutron, Glance, Cinder, Keystone, Horizon.  Optionally and
by default, Tacker and Congress services are also enabled.  Ceph is used as
the backend storage to Cinder on all deployed nodes.

Only a single controller is deployed in this scenario, which also includes
the OpenDaylight service on it.

Scenario usage overview
=======================

Simply deploy this scenario by using the os-odl-nofeature-noha.yaml deploy
settings file.

Limitations, Issues and Workarounds
===================================

* `APEX-112 <https://jira.opnfv.org/browse/APEX-112>`_:
   ODL routes local subnet traffic to GW
* `APEX-149 <https://jira.opnfv.org/browse/APEX-149>`_:
   OpenFlow rules are populated very slowly
* `APEX-268 <https://jira.opnfv.org/browse/APEX-268>`_:
   VMs with multiple floating IPs can only access via first NIC
* `APEX-422 <https://jira.opnfv.org/browse/APEX-422>`_:
   First nova instance DHCP request fails

References
==========

For more information on the OPNFV Fraser release, please visit
http://www.opnfv.org/fraser

