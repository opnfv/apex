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


%build
#rm requirements.txt
#/usr/bin/python setup.py build


%install
/usr/bin/python setup.py install --root=%{buildroot}

rm -rf %{buildroot}/usr/lib/python2.7/site-packages/congress_tempest_tests

install -d -m 755 %{buildroot}/var/log/congress/
install -d -m 755 %{buildroot}/etc/congress/snapshot/

install etc/api-paste.ini %{buildroot}/etc/congress/api-paste.ini
install etc/policy.json %{buildroot}/etc/congress/policy.json
tox -egenconfig
install etc/congress.conf.sample %{buildroot}/etc/congress/congress.conf

install -p -D -m 644 openstack-congress.service %{buildroot}%{_unitdir}/openstack-congress.service
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
/etc/congress/api-paste.ini
/etc/congress/congress.conf
/etc/congress/policy.json
/usr/bin/congress-db-manage
/usr/bin/congress-server
%{_unitdir}/openstack-congress.service
/usr/lib/python2.7/site-packages/congress
/usr/lib/python2.7/site-packages/congress_dashboard
/usr/lib/python2.7/site-packages/antlr3runtime

%dir %attr(0750, congress, root) %{_localstatedir}/log/congress

%changelog

