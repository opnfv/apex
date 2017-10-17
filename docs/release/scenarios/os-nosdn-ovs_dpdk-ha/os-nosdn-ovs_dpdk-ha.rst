.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>

This document provides scenario level details for Euphrates 1.0 of
deployment with no SDN controller and DPDK enabled Open vSwitch.

.. contents::
   :depth: 3
   :local:

Introduction
============

NFV and virtualized high performance applications, such as video processing,
require Open vSwitch to be accelerated with a fast data plane solution that
provides both carrier grade forwarding performance, scalability and open
extensibility.

A key component of any NFV solution is the virtual forwarder, which should
consist of soft switch that includes an accelerated data plane component. For
this, any virtual switch should make use of hardware accelerators and optimized
cache operation to be run in user space.

Scenario components and composition
===================================

This scenario enables high performance data plan acceleration by utilizing
DPDK enabled Open vSwitch (OVS).  This allows packet switching to be isolated
to particular hardware resources (CPUs, huge page memory allocation) without
kernel interrupt or context switching on the data plane CPU.

Tenant networking leverages Open vSwitch accelerated with a fast user space
data path such.  OVS with the Linux kernel module data path is used for all
other connectivity, such as connectivity to the external network (i.e. br-ex)
is performed via non-accelerated OVS.

Scenario Configuration
======================

Due to the performance optimization done by this scenario, it is recommended to
set some performance settings in the deploy settings in order to ensure maximum
performance.  This is not necessary unless doing a baremetal deployment.  Note,
this scenario requires taking the NIC mapped to the tenant network on the
compute node and binding it to DPDK.  This means it will no longer be
accessible via the kernel.  Ensure the NIC that is mapped to the Compute
Tenant network supports DPDK.

Make a copy of the deploy settings file, os-nosdn-ovs_dpdk-ha.yaml.  Under the
kernel options for Compute, edit as follows:
 - hugepagesz: the size of hugepages as an integer, followed by unit M
   (megabyte) or G (gigabyte).
 - hugepages: number of hugepages of hugepagesz size.  Huge page memory will be
   used for OVS as well as each nova instance spawned.  It is a good idea to
   allocate the maximum number possible, while still leaving some non-huge page
   memory available to other processes (nova-compute, etc).
 - isolcpus: comma-separated list of CPUs to isolate from the kernel.  Isolated
   CPUs will be used for pinning OVS and libvirtd to.

Under the performance->Compute->ovs section, edit as follows:
 - socket_memory: the amount of huge page memory in MB to allocate to allocate
   per socket to OVS as a comma-separated list.  It is best to allocate the
   memory to the socket which is closest to the PCI-Express bus of the NIC
   to be used with OVS DPDK for tenant traffic.
 - pmd_cores: comma-separated list of cores to pin to the poll-mode driver in
   OVS.  OVS DPDK will spawn TX/RX PMD threads to handle forwarding packets.
   This setting identifies which cores to pin these threads to.  For best
   performance, dedicate at least 2 isolated cores on the same NUMA node where
   socket_memory was assigned.
 - dpdk_cores: comma-separated list of cores to pin OVS lcore threads to.
   These threads do validation and control handling and it may not have any
   impact on performance to include this setting.

Under the performance->Compute section.  Add a nova subsection and include
the following setting:
 - libvirtpin: comma-separated list of CPUs to pin libvirt (nova) instances to.
   For best results, set this to be one or more CPUs that are located on the
   same NUMA node where OVS socket memory was dedicated.

Now deploy with the modified deploy settings file.

Limitations, Issues and Workarounds
===================================

* _APEX-415 br-phy dpdk interfaces are not brought up by os-net-config

References
==========

For more information on the OPNFV Euphrates release, please visit
http://www.opnfv.org/euphrates
