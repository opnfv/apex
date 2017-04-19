%define debug_package %{nil}

Name:		openstack-congress
Version:	2016.2
Release:	1%{?git}%{?dist}
Summary:	OpenStack servicevm/device manager

Group:		Applications/Internet
License:	Apache 2.0
URL:		https://wiki.openstack.org/wiki/Congress/Installation
Source0:	openstack-congress.tar.gz

BuildArch:	noarch

BuildRequires:	python-setuptools python2-oslo-config python2-debtcollector libffi-devel python-devel openssl-devel python2-oslo-config python2-debtcollector python34-devel

%description
OpenStack policy manager

%prep
%setup -q
rm requirements.txt

%build

%install
%{_bindir}/python setup.py install --root=%{buildroot}

rm -rf %{buildroot}%{_libdir}/python2.7/site-packages/congress_tempest_tests

install -d -m 755 %{buildroot}/var/log/congress/
install -d -m 755 %{buildroot}%{_sysconfdir}/congress/snapshot/

install etc/api-paste.ini %{buildroot}%{_sysconfdir}/congress/api-paste.ini
install etc/policy.json %{buildroot}%{_sysconfdir}/congress/policy.json
tox -e genconfig --workdir ../.tox
install etc/congress.conf.sample %{buildroot}/etc/congress/congress.conf

install -p -D -m 644 openstack-congress-server.service %{buildroot}%{_unitdir}/openstack-congress-server.service
install -d -m 755 %{buildroot}%{_sharedstatedir}/congress

%pre
getent group congress >/dev/null || groupadd -r congress
if ! getent passwd congress >/dev/null; then
  useradd -r -g congress -G congress,nobody -d %{_sharedstatedir}/congress -s /sbin/nologin -c "OpenStack Congress Daemon" congress
fi
exit 0

%post
%systemd_post openstack-congress

%preun
%systemd_preun openstack-congress

%postun
%systemd_postun_with_restart openstack-congress

%files
%{python2_sitelib}/congress-*.egg-info
%{_sysconfdir}/congress/api-paste.ini
%{_sysconfdir}/congress/congress.conf
%{_sysconfdir}/congress/policy.json
%{_bindir}/congress-db-manage
%{_bindir}/congress-server
%{_unitdir}/openstack-congress-server.service
%{_libdir}/python2.7/site-packages/congress
%{_libdir}/python2.7/site-packages/congress_dashboard
%{_libdir}/python2.7/site-packages/antlr3runtime

%dir %attr(0750, congress, root) %{_localstatedir}/log/congress

%changelog

