Name:		opnfv-apex
Version:	2.0
Release:	%{release}
Summary:	Overcloud Disk images for OPNFV Apex OpenDaylight deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

Provides:       opnfv-apex-sdn
BuildArch:	noarch
Requires:	opnfv-apex-common opnfv-apex-instack
Conflicts:      opnfv-apex-onos opnfv-apex-opencontrail

%description
Overcloud Disk images for OPNFV Apex OpenDaylight deployment
https://wiki.opnfv.org/apex

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/stack/
install build/stack/overcloud-full.qcow2 %{buildroot}%{_var}/opt/opnfv/stack/

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/stack/overcloud-full.qcow2

%changelog
* Mon Jan 11 2016 Dan Radez <dradez@redhat.com> - 2.0-1
- Package Split
