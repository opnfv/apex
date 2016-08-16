%define debug_package %{nil}

Name:		python-tackerclient
Version:	2015.2
Release:	1.trozet
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
#/usr/bin/python setup.py build


%install
/usr/bin/python setup.py install --prefix=%{buildroot} --install-lib=%{buildroot}/usr/lib/python2.7/site-packages
#rm -rf %{buildroot}/usr/lib/python2.7/site-packages/tacker/tests


%files
/bin/tacker
/usr/lib/python2.7/site-packages/tackerclient/*
/usr/lib/python2.7/site-packages/python_tackerclient-*

%changelog

