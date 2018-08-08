Introduction
============

This document describes the steps to install an OPNFV Fraser reference
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
These artifacts offer the choice of using the Apex bootable ISO
(``opnfv-apex-fraser.iso``) to both install CentOS 7 and the
necessary materials to deploy or the Apex RPMs (``opnfv-apex*.rpm``),
and their associated dependencies, which expects installation to a
CentOS 7 libvirt enabled host. The RPM contains a collection of
configuration files, prebuilt disk images, and the automatic deployment
script (``opnfv-deploy``).

An OPNFV install requires a "Jump Host" in order to operate.  The bootable
ISO will allow you to install a customized CentOS 7 release to the Jump Host,
which includes the required packages needed to run ``opnfv-deploy``.
If you already have a Jump Host with CentOS 7 installed, you may choose to
skip the ISO step and simply install the (``opnfv-apex*.rpm``) RPMs. The RPMs
are the same RPMs included in the ISO and include all the necessary disk
images and configuration files to execute an OPNFV deployment. Either method
will prepare a host to the same ready state for OPNFV deployment.

``opnfv-deploy`` instantiates a Triple-O Undercloud VM server using libvirt
as its provider.  This VM is then configured and used to provision the
OPNFV target deployment.  These nodes can be either virtual or bare metal.
This guide contains instructions for installing either method.
