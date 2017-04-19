%define debug_package %{nil}

Name:		python-tackerclient
Version:	2016.2
Release:	1%{?git}
Summary:	CLI and Client Library for OpenStack Networking

Group:		Applications/Internet
License:	Apache 2.0
URL:		https://wiki.openstack.org/wiki/Tacker/Installation
Source0:	python-tackerclient.tar.gz

BuildArch:	noarch
BuildRequires:	python-setuptools
#Requires:	stevedore>=1.5.0 http oslo.config>=1.11.0 oslo.messaging!=1.17.0!=1.17.1>=1.16.0 oslo.rootwrap>=2.0.0 python-novaclient>=2.22.0 

%description
CLI and Client Library for OpenStack Networking

%prep
%setup -q


%build
rm requirements.txt


%install
%{_bindir}/python setup.py install --prefix=%{buildroot} --install-lib=%{buildroot}%{_bindir}/python2.7/site-packages
#rm -rf %{buildroot}/usr/lib/python2.7/site-packages/tacker/tests


%files
/bin/tacker
%{_bindir}/python2.7/site-packages/tackerclient/*
%{_bindir}/python2.7/site-packages/python_tackerclient-*

%changelog
* Wed Nov 30 2016 Dan Radez <dradez@redhat.com> - 2016.2-1
- Version update for Newton

* Mon Jul 25 2016 Tim Rozet <trozet@redhat.com> - 2015.2-1
- Initial Commit
