%define name networking-vpp
#%define version %(python setup.py --version)
%define version 0.0.1 
%define release 1

Summary:   OpenStack Networking for VPP
Name:      %{name}
Version:   %{version}
Release:   %{release}%{?git}%{?dist}

License:   Apache 2.0
Group:     Applications/Internet
Source0:   networking-vpp.tar.gz
Url:       https://github.com/openstack/networking-vpp/

BuildArch: noarch
Requires:  vpp
Vendor:    OpenStack <openstack-dev@lists.openstack.org>
Packager:  Feng Pan <fpan@redhat.com>

%description
ML2 Mechanism driver and small control plane for OpenVPP forwarder

%prep
%setup -q
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
