Introduction
============

This document describes the steps to install an OPNFV Gambia reference
platform using the Apex installer.

The audience is assumed to have a good background in networking
and Linux administration.

Preface
=======

Apex uses Triple-O from the RDO Project OpenStack distribution as a
provisioning tool. The Triple-O image based life cycle installation
tool provisions an OPNFV Target System (1 or 3 controllers, 0 or more
compute nodes) with OPNFV specific configuration provided by the Apex
deployment tool chain.

The Apex deployment artifacts contain the necessary tools to deploy and
configure an OPNFV target system using the Apex deployment toolchain.
The Apex artifact is a python package capable of automating the installation of
TripleO and other OPNFV components.

An OPNFV install requires a "Jump Host" in order to operate.  It is required
to install CentOS 7 release to the Jump Host for traditional deployment,
which includes the required packages needed to run ``opnfv-deploy``.
If you already have a Jump Host with CentOS 7 installed, you may choose to
skip the ISO step and simply install the (``python34-opnfv-apex*.rpm``) RPM.

``opnfv-deploy`` instantiates a Triple-O Undercloud VM server using libvirt
as its provider.  This VM is then configured and used to provision the
OPNFV target deployment.  These nodes can be either virtual or bare metal.
This guide contains instructions for installing either method.
