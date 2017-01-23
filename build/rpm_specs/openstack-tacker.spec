%global pypi_name tacker

%{!?upstream_version: %global upstream_version %{version}%{?milestone}}

Name:           openstack-%{pypi_name}
Version:        0.5.0
Release:        1%{?dist}
Summary:        OpenStack Tacker Service

License:        ASL 2.0
URL:            https://launchpad.net/%{pypi_name}
Source0:        http://tarballs.openstack.org/%{pypi_name}/%{pypi_name}-%{version}.tar.gz
Source1:        openstack-tacker-server.service
Source2:        tacker.logrotate

BuildArch:      noarch

BuildRequires:  python2-devel
BuildRequires:  python2-setuptools
BuildRequires:  python2-routes
BuildRequires:  python-webob
BuildRequires:  python2-eventlet
BuildRequires:  python2-tosca-parser
BuildRequires:  python2-heatclient
BuildRequires:  python2-oslo-config
BuildRequires:  python2-oslo-log
BuildRequires:  python2-oslo-db
BuildRequires:  python2-oslo-policy
BuildRequires:  python2-oslo-service
BuildRequires:  python2-oslo-messaging
BuildRequires:  python2-oslo-sphinx
BuildRequires:  python2-neutronclient

Requires: python-%{pypi_name} = %{version}-%{release}
Requires: python-%{pypi_name}-doc = %{version}-%{release}

%description
Support of Tacker for OpenStack.

%package -n     python-%{pypi_name}
Summary:        OpenStack Tacker Service
%{?python_provide:%python_provide python2-%{pypi_name}}


%description -n python-%{pypi_name}
OpenStack Tacker Service is an open policy framework for OpenStack

# Documentation package
%package -n python-%{pypi_name}-doc
Summary:        Documentation for OpenStack Tacker service

BuildRequires:  python-sphinx

%description -n python-%{pypi_name}-doc
Documentation for OpenStack Tacker service

%prep
%autosetup -n %{pypi_name}-%{upstream_version}
# Remove bundled egg-info
rm -rf %{pypi_name}.egg-info

# Remove the requirements file so that pbr hooks don't add it
# to distutils requires_dist config
rm -rf {test-,}requirements.txt tools/{pip,test}-requires

%build
/usr/bin/python setup.py build
 
# Generate sample config and add the current directory to PYTHONPATH so
# oslo-config-generator doesn't skip tacker entry points.
PYTHONPATH=. oslo-config-generator --config-file=./etc/config-generator.conf --output-file=./etc/tacker.conf

# generate html docs 
sphinx-build doc/source html
# remove the sphinx-build leftovers
rm -rf html/.{doctrees,buildinfo}
 
%install
/usr/bin/python setup.py install --root=%{buildroot}
#-#remove tests
#-rm -rf %{buildroot}/usr/lib/python2.7/site-packages/tacker/tests
#-# Move config files from /usr/etc/ to /etc
#-mv %{buildroot}/usr/etc %{buildroot}
#-#install -p -D -m 644 apex/systemd/openstack-tacker.service %{buildroot}%{_unitdir}/openstack-tacker.service
#-# Remove egg-info
#-rm -rf %{buildroot}/usr/lib/python2.7/site-packages/*egg-info
#-
#-install -d -m 755 %{buildroot}%{_localstatedir}/cache/tacker
#-install -d -m 755 %{buildroot}%{_sharedstatedir}/tacker
mv %{buildroot}%{_usr}%{_sysconfdir} %{buildroot}
install -p -D -m 640 etc/tacker.conf %{buildroot}%{_sysconfdir}/tacker/tacker.conf

# Install systemd script
install -p -D -m 644 %{SOURCE1} %{buildroot}%{_unitdir}/openstack-tacker-server.service

# remove init script
rm -r %{buildroot}%{_sysconfdir}/init.d

# Install log file
install -d -m 755 %{buildroot}%{_localstatedir}/log/tacker
 
# Install logrotate
install -p -D -m 644 %{SOURCE2} %{buildroot}%{_sysconfdir}/logrotate.d/openstack-tacker

%pre
# 1777:1777 for tacker
getent group tacker >/dev/null || groupadd -r --gid 1777 tacker
getent passwd tacker >/dev/null || \
useradd --uid 1777 -r -g tacker -d %{_sharedstatedir}/tacker -s /sbin/nologin \
-c "OpenStack Tacker Daemons" tacker
exit 0

%post
%systemd_post openstack-tacker-server.service

%preun
%systemd_preun openstack-tacker-server.service

%postun
%systemd_postun_with_restart openstack-tacker-server.service

%files -n python-%{pypi_name}
%license LICENSE
%doc README.rst
%{python2_sitelib}/tacker*

%files
%{_bindir}/%{pypi_name}*
%config(noreplace) %attr(0644, root, root) %{_sysconfdir}/tacker/api-paste.ini
%config(noreplace) %attr(0644, root, root) %{_sysconfdir}/tacker/policy.json
%config(noreplace) %attr(0644, root, root) %{_sysconfdir}/tacker/tacker.conf
%config(noreplace) %attr(0644, root, root) %{_sysconfdir}/tacker/rootwrap.conf
%config(noreplace) %attr(0644, root, root) %{_sysconfdir}/rootwrap.d/tacker.filters
%{_unitdir}/openstack-tacker-server.service
%dir %attr(0755, tacker, tacker) %{_localstatedir}/log/tacker
%config(noreplace) %{_sysconfdir}/logrotate.d/openstack-tacker

%files -n python-%{pypi_name}-doc
%license LICENSE
%doc html


%changelog
* Mon Dec 19 2016 Dan Radez <dradez@redhat.com> - 0.5.0-1
- Initial Packaging
