Name:		opnfv-apex-common
Version:	2.0
Release:	%{release}
Summary:	Scripts for OPNFV deployment using RDO Manager

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-common.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch qemu-kvm python-docutils
Requires:	opnfv-apex-sdn opnfv-apex-instack openvswitch qemu-kvm bridge-utils libguestfs-tools

%description
Scripts for OPNFV deployment using RDO Manager
https://wiki.opnfv.org/apex

%prep
%setup -q

%build
rst2html docs/installation-instructions/installation-instructions.rst docs/installation-instructions.html
rst2html docs/release-notes/release-notes.rst docs/release-notes.html

%install
mkdir -p %{buildroot}%{_bindir}/
install ci/deploy.sh %{buildroot}%{_bindir}/opnfv-deploy
install ci/clean.sh %{buildroot}%{_bindir}/opnfv-clean

mkdir -p %{buildroot}%{_sysconfdir}/opnfv-apex/
install config/deploy/deploy_settings.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/deploy_settings.yaml
install config/deploy/network/network_settings.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/network_settings.yaml

mkdir -p %{buildroot}%{_var}/opt/opnfv/lib/
install lib/common-functions.sh %{buildroot}%{_var}/opt/opnfv/lib/

mkdir -p %{buildroot}%{_docdir}/opnfv/
install LICENSE.rst %{buildroot}%{_docdir}/opnfv/
install docs/installation-instructions/index.rst %{buildroot}%{_docdir}/opnfv/installation-instructions.rst
install docs/installation-instructions.html %{buildroot}%{_docdir}/opnfv/
install docs/release-notes/index.rst %{buildroot}%{_docdir}/opnfv/release-notes.rst
install docs/release-notes.html %{buildroot}%{_docdir}/opnfv/
install config/deploy/deploy_settings.yaml %{buildroot}%{_docdir}/opnfv/deploy_settings.yaml.example
install config/deploy/network/network_settings.yaml %{buildroot}%{_docdir}/opnfv/network_settings.yaml.example

%files
%defattr(644, root, root, -)
%attr(755,root,root) %{_bindir}/opnfv-deploy
%attr(755,root,root) %{_bindir}/opnfv-clean
%{_var}/opt/opnfv/lib/common-functions.sh
%{_sysconfdir}/opnfv-apex/deploy_settings.yaml
%{_sysconfdir}/opnfv-apex/network_settings.yaml
%doc %{_docdir}/opnfv/LICENSE.rst
%doc %{_docdir}/opnfv/installation-instructions.rst
%doc %{_docdir}/opnfv/installation-instructions.html
%doc %{_docdir}/opnfv/release-notes.rst
%doc %{_docdir}/opnfv/release-notes.html
%doc %{_docdir}/opnfv/deploy_settings.yaml.example
%doc %{_docdir}/opnfv/network_settings.yaml.example

%changelog
* Mon Jan 11 2016 Dan Radez <dradez@redhat.com> - 2.0-9
- Package Split
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
