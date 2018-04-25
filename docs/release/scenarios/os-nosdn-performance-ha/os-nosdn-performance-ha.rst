.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Fraser 1.0 of
deployment with no SDN controller and performance options enabled.

============
Introduction
============

This scenario is used primarily to demonstrate the performance settings and
capabilities in Apex. This scenario will  deploy a Pike OpenStack
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

The main purpose of this scenario is to serve as an example to show how to
set optional performance settings in an Apex deploy settings file.

Scenario usage overview
=======================

The performance options listed in os-nosdn-performance-ha.yaml give an example
of the different options a user can set in any deploy settings file.  Some
of these performance options are actually required for other scenarios which
rely on DPDK.  Options under the nova section like 'libvirtpin' allow a
user to choose which core to pin nova instances to on the overcloud compute
node.  Options under 'kernel' allow a user to set kernel specific arguments
at boot, which include options like hugepages, isolcpus, enabling iommu, etc.


Limitations, Issues and Workarounds
===================================

* `APEX-389 <https://jira.opnfv.org/browse/APEX-389>`_:
   Compute kernel parameters are applied to all nodes

References
==========

For more information on the OPNFV Fraser release, please visit
http://www.opnfv.org/fraser

