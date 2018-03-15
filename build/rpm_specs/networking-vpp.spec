%define release 1

Summary:   OpenStack Networking for VPP
Name:      python-networking-vpp
Version:   18.01
Release:   %{release}%{?git}%{?dist}

License:   Apache 2.0
Group:     Applications/Internet
Source0:   python-networking-vpp.tar.gz
Url:       https://github.com/openstack/networking-vpp/

BuildArch: noarch
AutoReq:   no
Requires:  vpp python-jwt
Vendor:    OpenStack <openstack-dev@lists.openstack.org>
Packager:  Feng Pan <fpan@redhat.com>

%description
ML2 Mechanism driver and small control plane for OpenVPP forwarder

%prep
%setup -q
cat << EOF > %{_builddir}/neutron-vpp-agent.service
[Unit]
Description=Networking VPP ML2 Agent

[Service]
ExecStartPre=/usr/bin/systemctl is-active vpp
ExecStart=/usr/bin/vpp-agent --config-file /etc/neutron/plugins/ml2/vpp_agent.ini --log-file /var/log/neutron/vpp-agent.log
Type=simple
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target

EOF

%preun
%systemd_preun neutron-vpp-agent.service

%postun
%systemd_postun
rm -rf %{python2_sitelib}/networking_vpp*

%install
python setup.py install -O1 --root=%{buildroot} --record=INSTALLED_FILES
mkdir -p %{buildroot}%{_libdir}/systemd/system
install %{_builddir}/neutron-vpp-agent.service %{buildroot}%{_unitdir}

%clean
rm -rf %{buildroot}

%files -f INSTALLED_FILES
%defattr(-,root,root)
%attr(644,root,root) %{_unitdir}/neutron-vpp-agent.service
