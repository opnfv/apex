Name:		opnfv-apex
Version:	2.1
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
* Thu Jan 14 2016 Dan Radez <dradez@redhat.com> - 2.1-2
- Package Split
* Wed Jan 13 2016 Dan Radez <dradez@redhat.com> - 2.1-1
- Incrementing Minor for Bramaputra RC release
* Sun Dec 20 2015 Tim Rozet <trozet@redhat.com> - 2.0-8
- Modifies networks to include OPNFV private/storage networks
* Tue Dec 15 2015 Dan Radez <dradez@redhat.com> - 2.0-7
- Added deploy settings for flat network config
- cleaned up files that don't need to be in the rpm
* Wed Dec 09 2015 Dan Radez <dradez@redhat.com> - 2.0-6
- Updating the OpenDaylight Patch
* Sat Dec 05 2015 Dan Radez <dradez@redhat.com> - 2.0-5
- Removing glance images
* Fri Nov 20 2015 Dan Radez <dradez@redhat.com> - 2.0-4
- Adding documentation
* Thu Nov 12 2015 Dan Radez <dradez@redhat.com> - 2.0-3
- OpenDaylight and Network Isolation support
* Wed Oct 21 2015 Dan Radez <dradez@redhat.com> - 2.0-2
- Initial deployment success using RPM packaging
* Fri Sep 25 2015 Dan Radez <dradez@redhat.com> - 2.0-1
- Migrated to RDO Manager
* Fri Apr 24 2015 Dan Radez <dradez@redhat.com> - 0.1-1
- Initial Packaging
