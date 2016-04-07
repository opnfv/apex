Name:		opnfv-apex-undercloud
Version:	3.0
Release:	%{release}
Summary:	Scripts and Disk images to launch the Undercloud for OPNFV Apex

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-undercloud.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch libvirt qemu-kvm python-docutils
Requires:	openvswitch libvirt qemu-kvm bridge-utils libguestfs-tools

%description
Scripts and Disk images to launch the Undercloud for OPNFV Apex
https://wiki.opnfv.org/apex

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/images/
mkdir -p %{buildroot}%{_var}/opt/opnfv/nics/

install build/undercloud.qcow2 %{buildroot}%{_var}/opt/opnfv/images/
install build/network-environment.yaml %{buildroot}%{_var}/opt/opnfv/
install build/common-environment.yaml %{buildroot}%{_var}/opt/opnfv/
install build/nics-controller.yaml.template %{buildroot}%{_var}/opt/opnfv/nics-controller.yaml.template
install build/nics-compute.yaml.template %{buildroot}%{_var}/opt/opnfv/nics-compute.yaml.template

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/images/undercloud.qcow2
%{_var}/opt/opnfv/network-environment.yaml
%{_var}/opt/opnfv/common-environment.yaml
%{_var}/opt/opnfv/nics-controller.yaml.template
%{_var}/opt/opnfv/nics-compute.yaml.template

%changelog
* Mon Apr 04 2016 Dan Radez <dradez@redhat.com> - 3.0-0
- Version update for Colorado
* Wed Mar 30 2016 Dan Radez <dradez@redhat.com> - 2.1-2
- Replacing NIC files with templates
* Thu Jan 14 2016 Dan Radez <dradez@redhat.com> - 2.1-1
- Package Split
