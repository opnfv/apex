Name:		opnfv-apex
Version:	2.0
Release:	1
Summary:	RDO Manager disk images for deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

#BuildRequires:	
Requires:	vagrant, VirtualBox-4.3

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

%files
/usr/bin/deploy.sh
/var/lib/libvirt/images/instack.qcow2

%changelog
* Fri Sep 25 2015 Dan Radez <dradez@redhatcom> - 2.0-1
- Migrated to RDO Manager
* Fri Apr 24 2015 Dan Radez <dradez@redhatcom> - 0.1-1
- Initial Packaging
