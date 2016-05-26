Name:		opnfv-apex-common
Version:	3.0
Release:	%{release}
Summary:	Scripts for OPNFV deployment using RDO Manager

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-common.tar.gz

BuildArch:	noarch
BuildRequires:	python-docutils python34-devel
Requires:	openstack-tripleo opnfv-apex-sdn opnfv-apex-undercloud openvswitch qemu-kvm bridge-utils libguestfs-tools
Requires:	initscripts net-tools iputils iproute iptables python34 python34-yaml python34-setuptools

%description
Scripts for OPNFV deployment using RDO Manager
https://wiki.opnfv.org/apex

%prep
%setup -q

%build
rst2html docs/installation-instructions/index.rst docs/installation-instructions.html
rst2html docs/release-notes/release-notes.rst docs/release-notes.html

%global __python %{__python3}

%install
mkdir -p %{buildroot}%{_bindir}/
install ci/deploy.sh %{buildroot}%{_bindir}/opnfv-deploy
install ci/clean.sh %{buildroot}%{_bindir}/opnfv-clean
install ci/util.sh %{buildroot}%{_bindir}/opnfv-util

mkdir -p %{buildroot}%{_sysconfdir}/opnfv-apex/
install config/deploy/os-nosdn-nofeature-noha.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/os-nosdn-nofeature-noha.yaml
install config/deploy/os-nosdn-nofeature-ha.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/os-nosdn-nofeature-ha.yaml
install config/deploy/os-odl_l2-nofeature-ha.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/os-odl_l2-nofeature-ha.yaml
install config/deploy/os-odl_l2-sfc-noha.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/os-odl_l2-sfc-noha.yaml
install config/deploy/os-odl_l3-nofeature-ha.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/os-odl_l3-nofeature-ha.yaml
install config/deploy/os-onos-nofeature-ha.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/os-onos-nofeature-ha.yaml
install config/deploy/os-ocl-nofeature-ha.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/os-ocl-nofeature-ha.yaml
install config/network/network_settings.yaml %{buildroot}%{_sysconfdir}/opnfv-apex/network_settings.yaml

mkdir -p %{buildroot}%{_var}/opt/opnfv/lib/python/apex
install lib/common-functions.sh %{buildroot}%{_var}/opt/opnfv/lib/
install lib/utility-functions.sh %{buildroot}%{_var}/opt/opnfv/lib/
install lib/python/apex-python-utils.py %{buildroot}%{_var}/opt/opnfv/lib/python/
mkdir -p %{buildroot}%{python3_sitelib}/apex/
install lib/python/apex/__init__.py %{buildroot}%{python3_sitelib}/apex/
install lib/python/apex/ip_utils.py %{buildroot}%{python3_sitelib}/apex/
install lib/python/apex/net_env.py %{buildroot}%{python3_sitelib}/apex/
install lib/python/apex/deploy_env.py %{buildroot}%{python3_sitelib}/apex/
mkdir -p %{buildroot}%{_var}/opt/opnfv/lib/installer/onos/
install lib/installer/onos/onos_gw_mac_update.sh %{buildroot}%{_var}/opt/opnfv/lib/installer/onos/

mkdir -p %{buildroot}%{_docdir}/opnfv/
install LICENSE.rst %{buildroot}%{_docdir}/opnfv/
install docs/installation-instructions.html %{buildroot}%{_docdir}/opnfv/
install docs/release-notes/index.rst %{buildroot}%{_docdir}/opnfv/release-notes.rst
install docs/release-notes.html %{buildroot}%{_docdir}/opnfv/
install config/deploy/deploy_settings.yaml %{buildroot}%{_docdir}/opnfv/deploy_settings.yaml.example
install config/network/network_settings.yaml %{buildroot}%{_docdir}/opnfv/network_settings.yaml.example
install config/inventory/pod_example_settings.yaml %{buildroot}%{_docdir}/opnfv/inventory.yaml.example

%files
%defattr(644, root, root, -)
%attr(755,root,root) %{_bindir}/opnfv-deploy
%attr(755,root,root) %{_bindir}/opnfv-clean
%attr(755,root,root) %{_bindir}/opnfv-util
%{_var}/opt/opnfv/lib/common-functions.sh
%{_var}/opt/opnfv/lib/utility-functions.sh
%{_var}/opt/opnfv/lib/python/
%{python3_sitelib}/apex/
%{_var}/opt/opnfv/lib/installer/onos/onos_gw_mac_update.sh
%{_sysconfdir}/opnfv-apex/os-nosdn-nofeature-noha.yaml
%{_sysconfdir}/opnfv-apex/os-nosdn-nofeature-ha.yaml
%{_sysconfdir}/opnfv-apex/os-odl_l2-nofeature-ha.yaml
%{_sysconfdir}/opnfv-apex/os-odl_l2-sfc-noha.yaml
%{_sysconfdir}/opnfv-apex/os-odl_l3-nofeature-ha.yaml
%{_sysconfdir}/opnfv-apex/os-onos-nofeature-ha.yaml
%{_sysconfdir}/opnfv-apex/os-ocl-nofeature-ha.yaml
%{_sysconfdir}/opnfv-apex/network_settings.yaml
%doc %{_docdir}/opnfv/LICENSE.rst
%doc %{_docdir}/opnfv/installation-instructions.html
%doc %{_docdir}/opnfv/release-notes.rst
%doc %{_docdir}/opnfv/release-notes.html
%doc %{_docdir}/opnfv/deploy_settings.yaml.example
%doc %{_docdir}/opnfv/network_settings.yaml.example
%doc %{_docdir}/opnfv/inventory.yaml.example

%changelog
* Sun May 15 2016 Feng Pan <fpan@redhat.com> - 3.0-5
- Fixes python3 dependency.
* Sun May 8 2016 Feng Pan <fpan@redhat.com> - 3.0-4
- Adds dependency for python34-setuptools
* Fri Apr 22 2016 Feng Pan <fpan@redhat.com> - 3.0-3
- Adds python network setting parsing lib.
* Fri Apr 15 2016 Feng Pan <fpan@redhat.com> - 3.0-2
- Adds python ip utility lib.
* Mon Apr 11 2016 Tim Rozet <trozet@redhat.com> - 3.0-1
- adding opnfv-util
* Mon Apr 04 2016 Dan Radez <dradez@redhat.com> - 3.0-0
- Version update for Colorado
* Mon Apr 04 2016 Dan Radez <dradez@redhat.com> - 2.2-0
- adding dependencies initscripts net-tools iputils iproute iptables
* Wed Jan 27 2016 Tim Rozet <trozet@redhat.com> - 2.1-4
- Adds example inventory file and nosdn scenario
* Wed Jan 20 2016 Dan Radez <dradez@redhat.com> - 2.1-3
- Updating the installation instructions
* Thu Jan 14 2016 Dan Radez <dradez@redhat.com> - 2.1-2
- Package Split
