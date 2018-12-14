.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Gambia 1.1 of
deployment with the OpenDaylight SDN controller and no extra features enabled.

============
Introduction
============

This scenario is used primarily to validate and deploy a Queens OpenStack
deployment with OpenDaylight, and without any NFV features enabled.

Scenario components and composition
===================================

This scenario is composed of common OpenStack services enabled by default,
including Nova, Neutron, Glance, Cinder, Keystone, Horizon.  Optionally and
by default, Tacker and Congress services are also enabled.  Ceph is used as
the backend storage to Cinder on all deployed nodes.

All services are in HA, meaning that there are multiple cloned instances of
each service, and they are balanced by HA Proxy using a Virtual IP Address
per service.

OpenDaylight is also enabled in HA, and forms a cluster.  Neutron
communicates with a Virtual IP Address for OpenDaylight which is load
balanced across the OpenDaylight cluster.  Every Open vSwitch node is
connected to every OpenDaylight for High Availability.

Scenario usage overview
=======================

Simply deploy this scenario by using the os-odl-nofeature-ha.yaml deploy
settings file.

Limitations, Issues and Workarounds
===================================

* `APEX-268 <https://jira.opnfv.org/browse/APEX-268>`_:
   VMs with multiple floating IPs can only access via first NIC

References
==========

For more information on the OPNFV Gambia release, please visit
http://www.opnfv.org/gambia

