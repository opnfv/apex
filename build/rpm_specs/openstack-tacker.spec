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
#remove init script
rm -fr %{buildroot}/etc/init.d

# Install systemd script
install -p -D -m 644 openstack-tacker-server.service %{buildroot}%{_unitdir}/openstack-tacker-server.service

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
%systemd_post openstack-tacker-server

%preun
%systemd_preun openstack-tacker-server

%postun
%systemd_postun_with_restart openstack-tacker-server

%files
/usr/bin/tacker-server
/usr/bin/tacker-db-manage
/usr/bin/tacker-rootwrap
%{_unitdir}/openstack-tacker-server.service
/usr/lib/python2.7/site-packages/tacker/*

#%config(noreplace) %attr(-, root, tacker) %{_sysconfdir}/tacker/tacker.conf`
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
