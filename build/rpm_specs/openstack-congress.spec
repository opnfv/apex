%define debug_package %{nil}

Name:		openstack-congress
Version:	2016.1
Release:	1%{?dist}
Summary:	OpenStack servicevm/device manager

Group:		Applications/Internet
License:	Apache 2.0
URL:		https://wiki.openstack.org/wiki/Congress/Installation
Source0:	openstack-congress.tar.gz

BuildArch:	noarch
BuildRequires:	python-setuptools python2-oslo-config python2-debtcollector
#Requires:	pbr>=0.8 Paste PasteDeploy>=1.5.0 Routes>=1.12.3!=2.0 anyjson>=0.3.3 argparse
#Requires:	Babel>=1.3 eventlet>=0.16.1!=0.17.0 greenlet>=0.3.2 httplib2>=0.7.5 requests>=2.2.0!=2.4.0
#Requires:	iso8601>=0.1.9 kombu>=2.5.0 netaddr>=0.7.12 SQLAlchemy<1.1.0>=0.9.7
#Requires:	WebOb>=1.2.3 python-heatclient>=0.3.0 python-keystoneclient>=1.1.0 alembic>=0.7.2 six>=1.9.0
#Requires:	stevedore>=1.5.0 http oslo.config>=1.11.0 oslo.messaging!=1.17.0!=1.17.1>=1.16.0 oslo.rootwrap>=2.0.0 python-novaclient>=2.22.0

%description
OpenStack policy manager

%prep
#git archive --format=tar.gz --prefix=openstack-congress-%{version}/ HEAD > openstack-congress.tar.gz

%setup -q


%build
#rm requirements.txt
#/usr/bin/python setup.py build


%install
/usr/bin/python setup.py install --prefix=%{buildroot} --install-lib=%{buildroot}/usr/lib/python2.7/site-packages

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

%config /etc/congress/congress.conf
/etc/congress/policy.json
/etc/congress/api-paste.ini
/bin/congress-server
/bin/congress-db-manage
%{_unitdir}/openstack-congress.service
/usr/lib/python2.7/site-packages/congress/*
/usr/lib/python2.7/site-packages/congress-*
/usr/lib/python2.7/site-packages/congress_tempest_tests/*
/usr/lib/python2.7/site-packages/antlr3runtime/*
%dir %attr(0750, congress, root) %{_localstatedir}/log/congress

%changelog

