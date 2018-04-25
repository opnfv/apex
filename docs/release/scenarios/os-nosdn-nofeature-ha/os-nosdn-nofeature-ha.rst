.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Euphrates 1.0 of
deployment with no SDN controller and no extra features enabled.

============
Introduction
============

This scenario is used primarily to validate and deploy a Pike OpenStack
deployment without any NFV features or SDN controller enabled.

Scenario components and composition
===================================

This scenario is composed of common OpenStack services enabled by default,
including Nova, Neutron, Glance, Cinder, Keystone, Horizon.  Optionally and
by default, Tacker and Congress services are also enabled.  Ceph is used as
the backend storage to Cinder on all deployed nodes.

All services are in HA, meaning that there are multiple cloned instances of
each service, and they are balanced by HA Proxy using a Virtual IP Address
per service.

Scenario usage overview
=======================

Simply deploy this scenario by using the os-nosdn-nofeature-ha.yaml deploy
settings file.

Limitations, Issues and Workarounds
===================================

None

References
==========

For more information on the OPNFV Fraser release, please visit
http://www.opnfv.org/fraser

