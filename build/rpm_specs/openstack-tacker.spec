%define debug_package %{nil}

Name:   openstack-tacker
Version:  2016.2
Release:  1%{?git}
Summary:  OpenStack servicevm/device manager

Group:    Applications/Internet
License:  Apache 2.0
URL:    https://wiki.openstack.org/wiki/Tacker/Installation
Source0:  openstack-tacker.tar.gz

BuildArch:  noarch
BuildRequires:  python-setuptools
#Requires:  pbr>=0.8 Paste PasteDeploy>=1.5.0 Routes>=1.12.3!=2.0 anyjson>=0.3.3 argparse
#Requires:  Babel>=1.3 eventlet>=0.16.1!=0.17.0 greenlet>=0.3.2 httplib2>=0.7.5 requests>=2.2.0!=2.4.0
#Requires:  iso8601>=0.1.9 kombu>=2.5.0 netaddr>=0.7.12 SQLAlchemy<1.1.0>=0.9.7
#Requires:  WebOb>=1.2.3 python-heatclient>=0.3.0 python-keystoneclient>=1.1.0 alembic>=0.7.2 six>=1.9.0
#Requires:  stevedore>=1.5.0 http oslo.config>=1.11.0 oslo.messaging!=1.17.0!=1.17.1>=1.16.0 oslo.rootwrap>=2.0.0 python-novaclient>=2.22.0 

%description
OpenStack servicevm/device manager

%prep
%setup -q


%build
rm requirements.txt
#/usr/bin/python setup.py build


%install
/usr/bin/python setup.py install --root=%{buildroot}
#remove tests
rm -rf %{buildroot}/usr/lib/python2.7/site-packages/tacker/tests
# Move config files from /usr/etc/ to /etc
mv %{buildroot}/usr/etc %{buildroot}
#install -p -D -m 644 apex/systemd/openstack-tacker.service %{buildroot}%{_unitdir}/openstack-tacker.service
# Remove egg-info
rm -rf %{buildroot}/usr/lib/python2.7/site-packages/*egg-info

install -d -m 755 %{buildroot}%{_localstatedir}/cache/tacker
install -d -m 755 %{buildroot}%{_sharedstatedir}/tacker
install -d -m 755 %{buildroot}%{_localstatedir}/log/tacker

%pre
getent group tacker >/dev/null || groupadd -r tacker
if ! getent passwd tacker >/dev/null; then
  useradd -r -g tacker -G tacker,nobody -d %{_sharedstatedir}/tacker -s /sbin/nologin -c "OpenStack Tacker Daemon" tacker
fi
exit 0

%post
%systemd_post openstack-tacker

%preun
%systemd_preun openstack-tacker

%postun
%systemd_postun_with_restart openstack-tacker

%files
/usr/bin/tacker-server
/usr/bin/tacker-db-manage
/usr/bin/tacker-rootwrap
#%{_unitdir}/openstack-tacker.service
#/etc/rootwrap.d/servicevm.filters
/usr/lib/python2.7/site-packages/tacker/*
###/usr/lib/python2.7/site-packages/tacker-*
#%config(noreplace) %attr(-, root, tacker) %{_sysconfdir}/tacker/api-paste.ini
%{_sysconfdir}/init.d/tacker-server
%{_sysconfdir}/rootwrap.d/tacker.filters
%{_sysconfdir}/tacker/api-paste.ini
%{_sysconfdir}/tacker/policy.json
%{_sysconfdir}/tacker/rootwrap.conf
%dir %attr(0750, tacker, root) %{_localstatedir}/cache/tacker
%dir %attr(0750, tacker, root) %{_sharedstatedir}/tacker
%dir %attr(0750, tacker, root) %{_localstatedir}/log/tacker

%changelog
* Wed Nov 30 2016 Dan Radez <dradez@redhat.com> - 2016.2-1
- Version update for Newton

* Mon Jul 25 2016 Tim Rozet <trozet@redhat.com> - 2015.2-1
- Initial Commit
