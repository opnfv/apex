.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Fraser 1.0 of
Kubernetes deployment with no SDN controller, no extra features
and no High Availability enabled.

============
Introduction
============

This scenario is used primarily to validate and deploy a Kubernetes
deployment without any NFV features or SDN controller enabled.

Scenario components and composition
===================================

This scenario first installs basic TripleO services in overcloud nodes
including Kernel, Ntp, Snmp, Timezone, TripleoPackages and Sshd, then
installs Kubernetes with kubespray.


Scenario usage overview
=======================

Simply deploy this scenario by using the k8s-nosdn-nofeature-noha.yaml deploy
settings file.

Limitations, Issues and Workarounds
===================================

None

References
==========

For more information on the OPNFV Fraser release, please visit
http://www.opnfv.org/fraser

