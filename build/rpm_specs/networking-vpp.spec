%define name networking-vpp
%define version %(python setup.py --version)
%define release 1
%define _topdir %(pwd)/build/rpm
%define _builddir %(pwd)
%define _rpmdir %(pwd)/build/rpm

Summary: OpenStack Networking for VPP
Name: %{name}
Version: %{version}
Release: %{release}
License: Apache 2.0
Group: Development/Libraries
BuildArch: noarch
Requires: vpp
Vendor: OpenStack <openstack-dev@lists.openstack.org>
Packager: Feng Pan <fpan@redhat.com>
Url: http://www.openstack.org/

%description
ML2 Mechanism driver and small control plane for OpenVPP forwarder

%prep
cat << EOF > %{_builddir}/networking-vpp-agent.service
[Unit]
Description=Networking VPP ML2 Agent

[Service]
ExecStartPre=/usr/bin/systemctl is-active vpp
ExecStart=/usr/bin/vpp-agent --config-file /etc/neutron/plugins/ml2/vpp_agent.ini
Type=simple
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target

EOF

%install
python setup.py install -O1 --root=$RPM_BUILD_ROOT --record=INSTALLED_FILES
mkdir -p %{buildroot}/usr/lib/systemd/system
install %{_builddir}/networking-vpp-agent.service %{buildroot}/usr/lib/systemd/system

%clean
rm -rf $RPM_BUILD_ROOT

%files -f INSTALLED_FILES
%defattr(-,root,root)
%attr(644,root,root) /usr/lib/systemd/system/networking-vpp-agent.service
