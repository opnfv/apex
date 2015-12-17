Name:		opnfv-apex
Version:	2.7
Release:	%{release}
Summary:	Scripts and Disk images for deployment

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex.tar.gz

BuildArch:	noarch
BuildRequires:	openvswitch qemu-kvm python-docutils
Requires:	openvswitch qemu-kvm bridge-utils libguestfs-tools

%description
These files are scripts and disk images used to launch the instack
libvirt VM and to load into the instack undercloud machine
to deploy an OpenStack overcloud. Installation is done via RDO Manager
https://rdoproject.org

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
mkdir -p %{buildroot}%{_var}/opt/opnfv/lib/

install lib/common-functions.sh %{buildroot}%{_var}/opt/opnfv/lib/
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

install build/instackenv-virt.json %{buildroot}%{_var}/opt/opnfv/
install build/instackenv.json.example %{buildroot}%{_var}/opt/opnfv/
install build/stack/overcloud-full.qcow2 %{buildroot}%{_var}/opt/opnfv/stack/

mkdir -p %{buildroot}%{_docdir}/opnfv/
install LICENSE.rst %{buildroot}%{_docdir}/opnfv/
install docs/installation-instructions/index.rst %{buildroot}%{_docdir}/opnfv/installation-instructions.rst
install docs/installation-instructions.html %{buildroot}%{_docdir}/opnfv/
install docs/release-notes/index.rst %{buildroot}%{_docdir}/opnfv/release-notes.rst
install docs/release-notes.html %{buildroot}%{_docdir}/opnfv/
install config/deploy/deploy_settings.yaml %{buildroot}%{_docdir}/opnfv/deploy_settings.yaml.example
install config/deploy/network/network_settings.yaml %{buildroot}%{_docdir}/opnfv/network_settings.yaml.example

%files
%{_bindir}/opnfv-deploy
%{_bindir}/opnfv-clean
%{_var}/opt/opnfv/lib/common-functions.sh
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
%{_var}/opt/opnfv/instackenv-virt.json
%{_var}/opt/opnfv/instackenv.json.example
%{_var}/opt/opnfv/stack/overcloud-full.qcow2
%doc %{_docdir}/opnfv/LICENSE.rst
%doc %{_docdir}/opnfv/installation-instructions.rst
%doc %{_docdir}/opnfv/installation-instructions.html
%doc %{_docdir}/opnfv/release-notes.rst
%doc %{_docdir}/opnfv/release-notes.html
%doc %{_docdir}/opnfv/deploy_settings.yaml.example
%doc %{_docdir}/opnfv/network_settings.yaml.example

%changelog
* Tue Dec 20 2015 Tim Rozet <trozet@redhat.com> - 2.7-1
- Modifies networks to include OPNFV private/storage networks
* Tue Dec 15 2015 Dan Radez <dradez@redhat.com> - 2.6-1
- Added deploy settings for flat network config
- cleaned up files that don't need to be in the rpm
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
