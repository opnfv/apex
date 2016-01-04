Name:		opnfv-apex-undercloud
Version:	2.1
Release:	%{release}
Summary:	Scripts and Disk images to launch Instack Undercloud for OPNFV Apex

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-undercloud.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch libvirt qemu-kvm python-docutils
Requires:	openvswitch libvirt qemu-kvm bridge-utils libguestfs-tools

%description
Scripts and Disk images to launch Instack Undercloud for OPNFV Apex
https://wiki.opnfv.org/apex

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/images/
mkdir -p %{buildroot}%{_var}/opt/opnfv/nics/

install build/undercloud.qcow2 %{buildroot}%{_var}/opt/opnfv/images/
install build/network-environment.yaml %{buildroot}%{_var}/opt/opnfv/
install build/nics/controller.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/controller_private.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/controller_storage.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_storage.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/controller_private_storage.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private_storage.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_br-ex.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private_br-ex.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_storage_br-ex.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private_storage_br-ex.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_storage_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private_storage_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_br-ex_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private_br-ex_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_storage_br-ex_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute_private_storage_br-ex_no-public-ip.yaml %{buildroot}%{_var}/opt/opnfv/nics/

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/images/undercloud.qcow2
%{_var}/opt/opnfv/network-environment.yaml
%{_var}/opt/opnfv/nics/controller.yaml
%{_var}/opt/opnfv/nics/compute.yaml
%{_var}/opt/opnfv/nics/controller_private.yaml
%{_var}/opt/opnfv/nics/compute_private.yaml
%{_var}/opt/opnfv/nics/controller_storage.yaml
%{_var}/opt/opnfv/nics/compute_storage.yaml
%{_var}/opt/opnfv/nics/controller_private_storage.yaml
%{_var}/opt/opnfv/nics/compute_private_storage.yaml
%{_var}/opt/opnfv/nics/compute_br-ex.yaml
%{_var}/opt/opnfv/nics/compute_private_br-ex.yaml
%{_var}/opt/opnfv/nics/compute_storage_br-ex.yaml
%{_var}/opt/opnfv/nics/compute_private_storage_br-ex.yaml
%{_var}/opt/opnfv/nics/compute_no-public-ip.yaml
%{_var}/opt/opnfv/nics/compute_private_no-public-ip.yaml
%{_var}/opt/opnfv/nics/compute_storage_no-public-ip.yaml
%{_var}/opt/opnfv/nics/compute_private_storage_no-public-ip.yaml
%{_var}/opt/opnfv/nics/compute_br-ex_no-public-ip.yaml
%{_var}/opt/opnfv/nics/compute_private_br-ex_no-public-ip.yaml
%{_var}/opt/opnfv/nics/compute_storage_br-ex_no-public-ip.yaml
%{_var}/opt/opnfv/nics/compute_private_storage_br-ex_no-public-ip.yaml

%changelog
* Thu Jan 14 2016 Dan Radez <dradez@redhat.com> - 2.1-1
- Package Split
