Name:		opnfv-apex
Version:	2.0
Release:	1
Summary:	RDO Manager disk images for deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

#BuildRequires:
#Requires:

%description
These files are disk images used to launch the instack
libvirt VM and to load into the instack undercloud machine
to deploy an OpenStack overcloud.

%prep
%setup -q


%build

%install
mkdir -p %{buildroot}/usr/bin/
cp ci/deploy.sh %{buildroot}/usr/bin/

mkdir -p %{buildroot}/var/lib/libvirt/images/
cp build/instack.qcow2 %{buildroot}/var/lib/libvirt/images/
cp build/baremetal_0.qcow2 %{buildroot}/var/lib/libvirt/images/
cp build/baremetal_1.qcow2 %{buildroot}/var/lib/libvirt/images/

mkdir -p %{buildroot}/etc/libvirt/qemu/
cp build/instack.xml %{buildroot}/etc/libvirt/qemu/
cp build/baremetal_0.xml %{buildroot}/etc/libvirt/qemu/
cp build/baremetal_1.xml %{buildroot}/etc/libvirt/qemu/

mkdir -p %{buildroot}/etc/libvirt/qemu/networks/
cp build/brbm.xml %{buildroot}/etc/libvirt/qemu/networks/

%files
/usr/bin/deploy.sh
/var/lib/libvirt/images/instack.qcow2
/var/lib/libvirt/images/baremetal_0.qcow2
/var/lib/libvirt/images/baremetal_1.qcow2
/etc/libvirt/qemu/instack.xml
/etc/libvirt/qemu/baremetal_0.xml
/etc/libvirt/qemu/baremetal_1.xml
/etc/libvirt/qemu/networks/brbm.xml

%changelog
* Fri Sep 25 2015 Dan Radez <dradez@redhatcom> - 2.0-1
- Migrated to RDO Manager
* Fri Apr 24 2015 Dan Radez <dradez@redhatcom> - 0.1-1
- Initial Packaging
