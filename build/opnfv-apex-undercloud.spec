Name:		opnfv-apex-undercloud
Version:	2.1
Release:	%{release}
Summary:	Scripts and Disk images to launch Instack Undercloud for OPNFV Apex

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-undercloud.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch qemu-kvm python-docutils
Requires:	openvswitch qemu-kvm bridge-utils libguestfs-tools

%description
Scripts and Disk images to launch Instack Undercloud for OPNFV Apex
https://wiki.opnfv.org/apex

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_var}/opt/opnfv/stack/
mkdir -p %{buildroot}%{_var}/opt/opnfv/nics/

install build/instack.qcow2 %{buildroot}%{_var}/opt/opnfv/stack/
install build/instack.xml %{buildroot}%{_var}/opt/opnfv/
install build/baremetalbrbm_brbm1_brbm2_brbm3_*.xml %{buildroot}%{_var}/opt/opnfv/
install build/brbm-net.xml %{buildroot}%{_var}/opt/opnfv/
install build/brbm1-net.xml %{buildroot}%{_var}/opt/opnfv/
install build/brbm2-net.xml %{buildroot}%{_var}/opt/opnfv/
install build/brbm3-net.xml %{buildroot}%{_var}/opt/opnfv/
install build/default-pool.xml %{buildroot}%{_var}/opt/opnfv/
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
install build/instackenv-virt.json %{buildroot}%{_var}/opt/opnfv/
install build/instackenv.json.example %{buildroot}%{_var}/opt/opnfv/

%files
%defattr(644, root, root, -)
%{_var}/opt/opnfv/stack/instack.qcow2
%{_var}/opt/opnfv/instack.xml
%{_var}/opt/opnfv/baremetalbrbm_brbm1_brbm2_brbm3_*.xml
%{_var}/opt/opnfv/brbm-net.xml
%{_var}/opt/opnfv/brbm1-net.xml
%{_var}/opt/opnfv/brbm2-net.xml
%{_var}/opt/opnfv/brbm3-net.xml
%{_var}/opt/opnfv/default-pool.xml
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
%{_var}/opt/opnfv/instackenv-virt.json
%{_var}/opt/opnfv/instackenv.json.example

%changelog
* Thu Jan 14 2016 Dan Radez <dradez@redhat.com> - 2.1-1
- Package Split
