Name:		opnfv-apex-onos
Version:	4.0
Release:	%{release}
Summary:	Overcloud Disk images for OPNFV Apex ONOS deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-onos.tar.gz

Provides:       opnfv-apex-sdn
BuildArch:	noarch
Requires:	opnfv-apex-common opnfv-apex-undercloud

%description
Overcloud Disk images for OPNFV Apex ONOS deployment
https://wiki.opnfv.org/apex

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/images/
install build/overcloud-full-onos.qcow2 %{buildroot}%{_var}/opt/opnfv/images/

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/images/overcloud-full-onos.qcow2

%changelog
* Wed Dec 7 2016 Tim Rozet <trozet@redhat.com> - 4.0-2
- Make install path consistent
* Wed Nov 2 2016 Dan Radez <dradez@redhat.com> - 4.0-1
- Version update for Danube
* Mon Apr 04 2016 Dan Radez <dradez@redhat.com> - 3.0-0
- Version update for Colorado
* Mon Mar 07 2016 Dan Radez <dradez@redhat.com> - 2.1-1
- Initial Packaging
