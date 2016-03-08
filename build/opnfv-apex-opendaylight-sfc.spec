Name:		opnfv-apex-opendaylight-sfc
Version:	2.1
Release:	%{release}
Summary:	Overcloud Disk images for OPNFV Apex OpenDaylight with SFC deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-opendaylight-sfc.tar.gz

Provides:       opnfv-apex-sdn
BuildArch:	noarch
Requires:	opnfv-apex-common opnfv-apex-undercloud

%description
Overcloud Disk images for OPNFV Apex OpenDaylight with SFC deployment
https://wiki.opnfv.org/apex

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/images/
install build/images/overcloud-full-opendaylight-sfc.qcow2 %{buildroot}%{_var}/opt/opnfv/images/

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/images/overcloud-full-opendaylight-sfc.qcow2

%changelog
* Tue Jan 19 2016 Dan Radez <dradez@redhat.com> - 2.1-1
- Initial Packaging
