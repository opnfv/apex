Name:		opnfv-apex
Version:	2.5
Release:	%{release}
Summary:	RDO Manager disk images for deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch qemu-kvm python-docutils
Requires:	openvswitch qemu-kvm bridge-utils libguestfs-tools

%description
These files are disk images used to launch the instack
libvirt VM and to load into the instack undercloud machine
to deploy an OpenStack overcloud.

%prep
%setup -q


%build
rst2html docs/installation-instructions/installation-instructions.rst docs/installation-instructions.html
rst2html docs/release-notes/index.rst docs/release-notes.html

%install
mkdir -p %{buildroot}%{_bindir}/
install ci/deploy.sh %{buildroot}%{_bindir}/opnfv-deploy
install ci/clean.sh %{buildroot}%{_bindir}/opnfv-clean

mkdir -p %{buildroot}%{_var}/opt/opnfv/stack/
mkdir -p %{buildroot}%{_var}/opt/opnfv/nics/

install build/instack.qcow2 %{buildroot}%{_var}/opt/opnfv/stack/
install build/instack.xml %{buildroot}%{_var}/opt/opnfv/
install build/baremetalbrbm_brbm1_*.xml %{buildroot}%{_var}/opt/opnfv/
install build/brbm-net.xml %{buildroot}%{_var}/opt/opnfv/
install build/brbm1-net.xml %{buildroot}%{_var}/opt/opnfv/
install build/default-pool.xml %{buildroot}%{_var}/opt/opnfv/
install build/network-environment.yaml %{buildroot}%{_var}/opt/opnfv/
install build/nics/controller.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/nics/compute.yaml %{buildroot}%{_var}/opt/opnfv/nics/
install build/opendaylight-puppet-neutron.patch %{buildroot}%{_var}/opt/opnfv/
install build/opendaylight-tripleo-heat-templates.patch %{buildroot}%{_var}/opt/opnfv/

install build/instackenv-virt.json %{buildroot}%{_var}/opt/opnfv/
install build/instackenv.json.example %{buildroot}%{_var}/opt/opnfv/
install build/stack/overcloud-full.qcow2 %{buildroot}%{_var}/opt/opnfv/stack/

mkdir -p %{buildroot}%{_docdir}/opnfv/
install LICENSE.rst %{buildroot}%{_docdir}/opnfv/
install docs/installation-instructions/index.rst %{buildroot}%{_docdir}/opnfv/installation-instructions.rst
install docs/installation-instructions.html %{buildroot}%{_docdir}/opnfv/
install docs/release-notes/index.rst %{buildroot}%{_docdir}/opnfv/release-notes.rst
install docs/release-notes.html %{buildroot}%{_docdir}/opnfv/

%files
%{_bindir}/opnfv-deploy
%{_bindir}/opnfv-clean
%{_var}/opt/opnfv/stack/instack.qcow2
%{_var}/opt/opnfv/instack.xml
%{_var}/opt/opnfv/baremetalbrbm_brbm1_*.xml
%{_var}/opt/opnfv/brbm-net.xml
%{_var}/opt/opnfv/brbm1-net.xml
%{_var}/opt/opnfv/default-pool.xml
%{_var}/opt/opnfv/network-environment.yaml
%{_var}/opt/opnfv/nics/controller.yaml
%{_var}/opt/opnfv/nics/compute.yaml
%{_var}/opt/opnfv/opendaylight-puppet-neutron.patch
%{_var}/opt/opnfv/opendaylight-tripleo-heat-templates.patch
%{_var}/opt/opnfv/instackenv-virt.json
%{_var}/opt/opnfv/instackenv.json.example
%{_var}/opt/opnfv/stack/overcloud-full.qcow2
%doc %{_docdir}/opnfv/LICENSE.rst
%doc %{_docdir}/opnfv/installation-instructions.rst
%doc %{_docdir}/opnfv/installation-instructions.html
%doc %{_docdir}/opnfv/release-notes.rst
%doc %{_docdir}/opnfv/release-notes.html


%changelog
* Wed Dec 09 2015 Dan Radez <dradez@redhat.com> - 2.5-1
- Updating the OpenDaylight Patch
* Fri Dec 05 2015 Dan Radez <dradez@redhat.com> - 2.4-1
- Removing glance images
* Fri Nov 20 2015 Dan Radez <dradez@redhat.com> - 2.3-1
- Adding documentation
* Thu Nov 12 2015 Dan Radez <dradez@redhat.com> - 2.2-1
- OpenDaylight and Network Isolation support
* Wed Oct 21 2015 Dan Radez <dradez@redhat.com> - 2.1-1
- Initial deployment success using RPM packaging
* Fri Sep 25 2015 Dan Radez <dradez@redhat.com> - 2.0-1
- Migrated to RDO Manager
* Fri Apr 24 2015 Dan Radez <dradez@redhat.com> - 0.1-1
- Initial Packaging
