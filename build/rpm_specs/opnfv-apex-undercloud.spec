Name:		opnfv-apex-undercloud
Version:	6.0
Release:	%{_release}
Summary:	Scripts and Disk images to launch the Undercloud for OPNFV Apex

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-undercloud.tar.gz

BuildArch:	noarch
BuildRequires:	python34-docutils
Requires:	openvswitch libvirt qemu-kvm bridge-utils libguestfs-tools

%description
Scripts and Disk images to launch the Undercloud for OPNFV Apex
https://wiki.opnfv.org/apex

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/images/
mkdir -p %{buildroot}%{_var}/opt/opnfv/nics/

install build/undercloud.qcow2 %{buildroot}%{_var}/opt/opnfv/images/
install build/network-environment.yaml %{buildroot}%{_var}/opt/opnfv/
install build/nics-template.yaml.jinja2 %{buildroot}%{_var}/opt/opnfv/

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/images/undercloud.qcow2
%{_var}/opt/opnfv/network-environment.yaml
%{_var}/opt/opnfv/nics-template.yaml.jinja2


%changelog
* Wed Nov 29 2017 Tim Rozet <trozet@redhat.com> - 6.0-0
  Bump version for Fraser
* Tue Apr 04 2017 Dan Radez <dradez@redhat.com> - 5.0-1
- Version update for Euphrates
* Wed Nov 2 2016 Dan Radez <dradez@redhat.com> - 4.0-1
- Version update for Danube
* Tue May 24 2016 Tim Rozet <trozet@redhat.com> - 3.0-1
- Adds jinja2 nic templates
* Mon Apr 04 2016 Dan Radez <dradez@redhat.com> - 3.0-0
- Version update for Colorado
* Wed Mar 30 2016 Dan Radez <dradez@redhat.com> - 2.1-2
- Replacing NIC files with templates
* Thu Jan 14 2016 Dan Radez <dradez@redhat.com> - 2.1-1
- Package Split
