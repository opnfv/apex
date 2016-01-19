Triple-O Deployment Architecture
================================

Apex is based on RDO Manager which is the RDO Project's implementation of
the OpenStack Triple-O project.  It is important to understand the basics
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
baremetal provisioning.  RDO Manager's deployment of the undercloud is
call Instack. Instack will be deployed as a virtual machine on a jumphost.
This VM is pre-built and distributed as part of the Apex RPM.

The overcloud is OPNFV. Configuration will be passed into Instack and
Instack will use OpenStack's orchestration component call Heat to
execute a deployment will provision the target nodes to become OPNFV.
