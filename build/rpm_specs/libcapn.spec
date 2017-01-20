Name:           libcapn
Version:        1.0
Release:        0
Summary:        capnproto lib for customized quagga

Group:          System Environment
License:        Apache 2.0
URL:            https://gerrit.opnfv.org/gerrit/apex.git
Source0:        libcapn.tar.gz

Provides:   libcapn

%description
customized quagga lib capnproto

%prep
%setup -q

%install
mkdir -p %{buildroot}/%{_libdir}
install %{_builddir}/libcapn.so.1 %{buildroot}/%{_libdir}/
install %{_builddir}/libcapn.so %{buildroot}/%{_libdir}/

%post -p /sbin/ldconfig

%postun -p /sbin/ldconfig

%files
%defattr(-,root,root)
%{_libdir}/libcapn.so.1
%{_libdir}/libcapn.so

%changelog
* Mon Jan 23 2017 Tim Rozet <trozet@redhat.com> - 1.0-1
- Initial version
