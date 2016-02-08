Introduction
============

This document describes the steps to install an OPNFV Bramaputra reference
platform, as defined by the Genesis Project using the Apex installer.

The audience is assumed to have a good background in networking
and Linux administration.

Preface
=======

Apex uses the RDO Manager Open Source project as a server provisioning tool.
RDO Manager is the RDO Project implimentation of OpenStack's Triple-O project.
The Triple-O image based life cycle installation tool provisions an OPNFV
Target System (3 controllers, n number of compute nodes) with OPNFV specific
configuration provided by the Apex deployment tool chain.

The Apex deployment artifacts contain the necessary tools to deploy and
configure an OPNFV target system using the Apex deployment toolchain.
These artifacts offer the choice of using the Apex bootable ISO
(``opnfv-apex-bramaputra.iso``) to both install CentOS 7 and the
nessesary materials to deploy or the Apex RPM (``opnfv-apex.rpm``)
which expects installation to a CentOS 7 libvirt enabled host. The RPM
contains a collection of configuration file, prebuilt disk images,
and the automatic deployment script (``opnfv-deploy``).

An OPNFV install requires a "Jumphost" in order to operate.  The bootable
ISO will allow you to install a customized CentOS 7 release to the Jumphost,
which includes the required packages needed to run ``opnfv-deploy``.
If you already have a Jumphost with CentOS 7 installed, you may choose to
skip the ISO step and simply install the (``opnfv-apex.rpm``) RPM. The RPM
is the same RPM included in the ISO and includes all the necessary disk
images and configuration files to execute an OPNFV deployment. Either method
will prepare a host to the same ready state for OPNFV deployment.

``opnfv-deploy`` instantiates an RDO Manager Instack VM server using libvirt
as its provider.  This VM is then configured and used to provision the
OPNFV target deployment (3 controllers, n compute nodes).  These nodes can
be either virtual or bare metal. This guide contains instructions for
installing either method.
