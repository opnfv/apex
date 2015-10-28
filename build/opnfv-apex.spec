Name:		opnfv-apex
Version:	2.1
Release:	%{release}
Summary:	RDO Manager disk images for deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch qemu-kvm
Requires:	openvswitch qemu-kvm bridge-utils libguestfs-tools

%description
These files are disk images used to launch the instack
libvirt VM and to load into the instack undercloud machine
to deploy an OpenStack overcloud.

%prep
%setup -q


%build

%install
mkdir -p %{buildroot}%{_bindir}/
cp ci/deploy.sh %{buildroot}%{_bindir}/opnfv-deploy
cp ci/clean.sh %{buildroot}%{_bindir}/opnfv-clean

mkdir -p %{buildroot}%{_var}/opt/opnfv/stack/

cp build/instack.qcow2 %{buildroot}%{_var}/opt/opnfv/stack/
cp build/instack.xml %{buildroot}%{_var}/opt/opnfv/
cp build/baremetalbrbm_*.xml %{buildroot}%{_var}/opt/opnfv/
cp build/brbm-net.xml %{buildroot}%{_var}/opt/opnfv/
cp build/default-pool.xml %{buildroot}%{_var}/opt/opnfv/

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
%{_bindir}/opnfv-deploy
%{_bindir}/opnfv-clean
%{_var}/opt/opnfv/stack/instack.qcow2
%{_var}/opt/opnfv/instack.xml
%{_var}/opt/opnfv/baremetalbrbm_*.xml
%{_var}/opt/opnfv/brbm-net.xml
%{_var}/opt/opnfv/default-pool.xml
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
* Wed Oct 21 2015 Dan Radez <dradez@redhatcom> - 2.1-1
- Initial deployment success using RPM packaging
* Fri Sep 25 2015 Dan Radez <dradez@redhatcom> - 2.0-1
- Migrated to RDO Manager
* Fri Apr 24 2015 Dan Radez <dradez@redhatcom> - 0.1-1
- Initial Packaging
