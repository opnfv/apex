Name:		opnfv-apex-release
Version:	euphrates
Release:	%{release}
Summary:	RPM Release file

Group:		System Environment
License:	Apache 2.0
URL:		https://gerrit.opnfv.org/gerrit/apex.git
Source0:	opnfv-apex-release.tar.gz

BuildArch:	noarch
Requires:	rdo-release = newton epel-release libvirt-python

%description
RPM Release file that provides a yum repo file to install OPNFV Apex

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_sysconfdir}/yum.repos.d/
install config/yum.repos.d/opnfv-apex.repo %{buildroot}%{_sysconfdir}/yum.repos.d/

%files
%defattr(644, root, root, -)
%{_sysconfdir}/yum.repos.d/opnfv-apex.repo

%changelog
* Tue Apr 04 2017 Dan Radez <dradez@redhat.com> - 5.0-1
- Version update for Euphrates
* Wed Nov 23 2016 Dan Radez <dradez@redhat.com> - 3.0-1
- Initial Packaging
