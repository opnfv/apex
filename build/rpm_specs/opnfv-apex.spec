Name:		opnfv-apex
Version:	6.0
Release:	%{_release}
Summary:	Overcloud Disk images for OPNFV Apex OpenDaylight deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

<<<<<<< HEAD
Provides:	opnfv-apex-sdn
BuildArch:	noarch
Requires:	python34-opnfv-apex opnfv-apex-undercloud
=======
BuildArch:      noarch
BuildRequires:  python34-docutils python34-devel
Requires:       openvswitch qemu-kvm bridge-utils libguestfs-tools python34-libvirt
Requires:       initscripts net-tools iputils iproute iptables python34 python34-yaml python34-jinja2 python3-ipmi python34-virtualbmc
Requires:       ipxe-roms-qemu >= 20160127-1
Requires:       libvirt-devel ansible
Requires:       python34-iptables python34-cryptography python34-pbr
Requires:       python34-GitPython python34-pygerrit2 python34-distro
Requires:       git
>>>>>>> 5255775... Adding git as required dependency for Apex RPMs

%description
Overcloud Disk images for OPNFV Apex OpenDaylight deployment
https://wiki.opnfv.org/apex

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/images/
install build/overcloud-full-opendaylight.qcow2 %{buildroot}%{_var}/opt/opnfv/images/
install build/overcloud-full.vmlinuz %{buildroot}%{_var}/opt/opnfv/images/
install build/overcloud-full.initrd  %{buildroot}%{_var}/opt/opnfv/images/

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/images/overcloud-full-opendaylight.qcow2
%{_var}/opt/opnfv/images/overcloud-full.vmlinuz
%{_var}/opt/opnfv/images/overcloud-full.initrd

%changelog
* Wed Nov 29 2017 Tim Rozet <trozet@redhat.com> - 6.0-0
  Bump version for Fraser
* Wed Aug 23 2017 Tim Rozet <trozet@redhat.com> - 5.0-3
- Updated requirements
* Fri May 26 2017 Tim Rozet <trozet@redhat.com> - 5.0-2
- Fixes missing ramdisk and kernel
* Tue Apr 04 2017 Dan Radez <dradez@redhat.com> - 5.0-1
- Version update for Euphrates
* Wed Dec 7 2016 Tim Rozet <trozet@redhat.com> - 4.0-2
- Make install path consistent
* Wed Nov 2 2016 Dan Radez <dradez@redhat.com> - 4.0-1
- Version update for Danube
* Mon Apr 04 2016 Dan Radez <dradez@redhat.com> - 3.0-0
- Version update for Colorado
* Wed Jan 20 2016 Dan Radez <dradez@redhat.com> - 2.1-4
- cleaning out libvirt config files
- replacing instack-virt-setup with direct tripleo calls
* Tue Jan 19 2016 Dan Radez <dradez@redhat.com> - 2.1-3
- Remove conflicts with other SDN controllers, they can co-exist now
- update overcloud image name to specify opendaylight
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
