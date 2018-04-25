.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Fraser 1.0 of
deployment with the OVN SDN controller and no extra features enabled.

============
Introduction
============

This scenario is used primarily to validate and deploy a Pike OpenStack
deployment with the OVN SDN controller, and without any NFV features enabled.

Scenario components and composition
===================================

This scenario is composed of common OpenStack services enabled by default,
including Nova, Neutron, Glance, Cinder, Keystone, Horizon.  Optionally and
by default, Tacker and Congress services are also enabled.  Ceph is used as
the backend storage to Cinder on all deployed nodes.

Scenario usage overview
=======================

Simply deploy this scenario by using the os-ovn-nofeature-noha.yaml deploy
settings file.

Limitations, Issues and Workarounds
===================================

* `APEX-430 <https://jira.opnfv.org/browse/APEX-430>`_:
   OVN HA functionality is not available.

References
==========

For more information on the OPNFV Fraser release, please visit
http://www.opnfv.org/fraser

