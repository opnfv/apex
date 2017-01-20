Name:           c-capnproto
Version:        0.1
Release:        0
Summary:        C library/compiler for the Cap'n Proto serialization/RPC protocol

Group:          System Environment
License:        Apache 2.0
URL:            https://gerrit.opnfv.org/gerrit/apex.git
Source0:        %{name}-%{version}.tar.gz

Provides:   c_capnproto

%description
C library/compiler for the Cap'n Proto serialization/RPC protocol

%prep
%setup -q

%build
%configure --without-gtest

%install
rm -rf $RPM_BUILD_ROOT
%make_install
find %{buildroot} -name '*.la' -exec rm -f {} ';'
find %{buildroot} -name '*.a' -exec rm -f {} ';'
mkdir -p $RPM_BUILD_ROOT/%{_includedir}/c-capnproto/
# These are the headers/libs quagga/zrpcd link against
install -m 700 $RPM_BUILD_ROOT/%{_includedir}/capn.h $RPM_BUILD_ROOT/%{_includedir}/c-capnproto/
install -m 700 $RPM_BUILD_ROOT/%{_libdir}/libcapn.so $RPM_BUILD_ROOT/%{_libdir}/libcapn_c.so

%files 
%defattr(-,root,root)
%{_bindir}/capnpc-c
%{_includedir}/capn.h
%{_includedir}/c-capnproto/capn.h
%{_libdir}/libcapn.so*
%{_libdir}/libcapn_c.so

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Jan 23 2017 Tim Rozet <trozet@redhat.com> - 1.0-1
- Initial version
