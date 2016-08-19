Triple-O Deployment Architecture
================================

Apex is based on the OpenStack Triple-O project as distributed by
the RDO Project.  It is important to understand the basics
of a Triple-O deployment to help make decisions that will assist in
successfully deploying OPNFV.

Triple-O stands for OpenStack On OpenStack.  This means that OpenStack
will be used to install OpenStack. The target OPNFV deployment is an
OpenStack cloud with NFV features built-in that will be deployed by a
smaller all-in-one deployment of OpenStack.  In this deployment
methodology there are two OpenStack installations. They are referred
to as the undercloud and the overcloud. The undercloud is used to
deploy the overcloud.

The undercloud is the all-in-one installation of OpenStack that includes
baremetal provisioning capability.  The undercloud will be deployed as a
virtual machine on a jumphost.  This VM is pre-built and distributed as part
of the Apex RPM.

The overcloud is OPNFV. Configuration will be passed into undercloud and
the undercloud will use OpenStack's orchestration component, named Heat, to
execute a deployment that will provision the target OPNFV nodes.

OPNFV Scenario Architecture
===========================

OPNFV distinguishes different types of SDN controllers, deployment options, and
features into "scenarios".  These scenarios are universal across all OPNFV
installers, although some may or may not be supported by each installer.

The standard naming convention for a scenario is:
<VIM platform>-<SDN type>-<feature>-<ha/noha>

The only supported VIM type is "OS" (OpenStack), while SDN types can be any
supported SDN controller.  "feature" includes things like ovs_dpdk, sfc, etc.
"ha" or "noha" determines if the deployment will be highly available.  If "ha"
is used at least 3 control nodes are required.

OPNFV Scenarios in Apex
=======================

Apex provides pre-built scenario files in /etc/opnfv-apex which a user can
select from to deploy the desired scenario.  Simply pass the desired file to
the installer as a (-d) deploy setting.  Read further in the Apex documentation
to learn more about invoking the deploy command.  Below is quick reference
matrix for OPNFV scenarios supported in Apex.  Please refer to the respective
OPNFV Docs documentation for each scenario in order to see a full scenario
description.  The following scenarios correspond to a supported <Scenario>.yaml
deploy settings file:

+-------------------------+------------+-----------------+
| **Scenario**            | **Owner**  | **Known Issues**|
+-------------------------+------------+-----------------+
| os-nosdn-nofeature-ha   | Apex       |                 |
+-------------------------+------------+-----------------+
| os-nosdn-nofeature-noha | Apex       |                 |
+-------------------------+------------+-----------------+
| os-nosdn-ovs-noha       | OVS for NFV|                 |
+-------------------------+------------+-----------------+
| os-nosdn-fdio-noha      | FDS        |                 |
+-------------------------+------------+-----------------+
| os-odl_l2-nofeature-ha  | Apex       |                 |
+-------------------------+------------+-----------------+
| os-odl_l3-nofeature-ha  | Apex       | APEX-112        |
+-------------------------+------------+-----------------+
| os-odl_l2-sfc-noha      | SFC        |                 |
+-------------------------+------------+-----------------+
| os-odl_l2-bgpvpn-noha   | SDNVPN     |                 |
+-------------------------+------------+-----------------+
| os-odl_l2-fdio-noha     | FDS        |                 |
+-------------------------+------------+-----------------+
| os-onos-nofeature-ha    | ONOSFW     |                 |
+-------------------------+------------+-----------------+
| os-onos-sfc-ha          | ONOSFW     |                 |
+-------------------------+------------+-----------------+
