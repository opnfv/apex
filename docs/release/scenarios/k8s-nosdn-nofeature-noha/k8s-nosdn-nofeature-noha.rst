.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Gambia 1.1 of
Kubernetes deployment with no SDN controller, no extra features
and no High Availability enabled. Note this scenario is *not* supported
for Gambia initial release and will be supported in a later service release
of Gambia.

============
Introduction
============

This scenario is used primarily to validate and deploy a Kubernetes
deployment without any NFV features or SDN controller enabled.

Scenario components and composition
===================================

This scenario deploys a Kubernetes cluster on bare metal or virtual
environment with a single master node. TripleO is used to bootstrap
all the nodes and set up basic services like SSH. An undercloud VM
used similarly to Openstack deployments, however no Openstack services
(Nova, Neutron, Keystone, etc) will be deployed to the nodes. After
TripleO successfully executes all the bootstrapping tasks, Kubespray
is run (using ansible) to deploy Kubernetes cluster on the nodes.


Scenario usage overview
=======================

Simply deploy this scenario by using the k8s-nosdn-nofeature-noha.yaml deploy
settings file.

Limitations, Issues and Workarounds
===================================

None

References
==========

For more information on the OPNFV Gambia release, please visit
http://www.opnfv.org/gambia

