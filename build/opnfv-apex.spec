Name:		opnfv-apex
Version:	2.0
Release:	%{release}
Summary:	RDO Manager disk images for deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch libvirt qemu-kvm
Requires:	openvswitch libvirt qemu-kvm bridge-utils libguestfs-tools

%description
These files are disk images used to launch the instack
libvirt VM and to load into the instack undercloud machine
to deploy an OpenStack overcloud.

%prep
%setup -q


%build

%install
mkdir -p %{buildroot}%{_bindir}/
cp ci/deploy.sh %{buildroot}%{_bindir}/

mkdir -p %{buildroot}%{_sharedstatedir}/libvirt/images/
cp build/instack.qcow2 %{buildroot}%{_sharedstatedir}/libvirt/images/
cp build/baremetalbrbm_0.qcow2 %{buildroot}%{_sharedstatedir}/libvirt/images/
cp build/baremetalbrbm_1.qcow2 %{buildroot}%{_sharedstatedir}/libvirt/images/

mkdir -p %{buildroot}%{_sysconfdir}/libvirt/qemu/
cp build/instack.xml %{buildroot}%{_sysconfdir}/libvirt/qemu/
cp build/baremetalbrbm_0.xml %{buildroot}%{_sysconfdir}/libvirt/qemu/
cp build/baremetalbrbm_1.xml %{buildroot}%{_sysconfdir}/libvirt/qemu/

mkdir -p %{buildroot}%{_sysconfdir}/libvirt/qemu/networks/
cp build/brbm.xml %{buildroot}%{_sysconfdir}/libvirt/qemu/networks/

mkdir -p %{buildroot}%{_var}/opt/opnfv/stack/
cp build/instackenv-virt.json %{buildroot}%{_var}/opt/opnfv/
cp build/stack/deploy-ramdisk-ironic.initramfs %{buildroot}%{_var}/opt/opnfv/stack/
cp build/stack/deploy-ramdisk-ironic.kernel %{buildroot}%{_var}/opt/opnfv/stack/
cp build/stack/ironic-python-agent.initramfs %{buildroot}%{_var}/opt/opnfv/stack/
cp build/stack/ironic-python-agent.kernel %{buildroot}%{_var}/opt/opnfv/stack/
cp build/stack/ironic-python-agent.vmlinuz %{buildroot}%{_var}/opt/opnfv/stack/
cp build/stack/overcloud-full.initrd %{buildroot}%{_var}/opt/opnfv/stack/
cp build/stack/overcloud-full.qcow2 %{buildroot}%{_var}/opt/opnfv/stack/
cp build/stack/overcloud-full.vmlinuz %{buildroot}%{_var}/opt/opnfv/stack/

%files
%{_bindir}/deploy.sh
%{_sharedstatedir}/libvirt/images/instack.qcow2
%{_sharedstatedir}/libvirt/images/baremetalbrbm_0.qcow2
%{_sharedstatedir}/libvirt/images/baremetalbrbm_1.qcow2
%{_sysconfdir}/libvirt/qemu/instack.xml
%{_sysconfdir}/libvirt/qemu/baremetalbrbm_0.xml
%{_sysconfdir}/libvirt/qemu/baremetalbrbm_1.xml
%{_sysconfdir}/libvirt/qemu/networks/brbm.xml
%{_var}/opt/opnfv/instackenv-virt.json
%{_var}/opt/opnfv/stack/deploy-ramdisk-ironic.initramfs
%{_var}/opt/opnfv/stack/deploy-ramdisk-ironic.kernel
%{_var}/opt/opnfv/stack/ironic-python-agent.initramfs
%{_var}/opt/opnfv/stack/ironic-python-agent.kernel
%{_var}/opt/opnfv/stack/ironic-python-agent.vmlinuz
%{_var}/opt/opnfv/stack/overcloud-full.initrd
%{_var}/opt/opnfv/stack/overcloud-full.qcow2
%{_var}/opt/opnfv/stack/overcloud-full.vmlinuz

%changelog
* Fri Sep 25 2015 Dan Radez <dradez@redhatcom> - 2.0-1
- Migrated to RDO Manager
* Fri Apr 24 2015 Dan Radez <dradez@redhatcom> - 0.1-1
- Initial Packaging
