Name: zrpcd
Version: 0.2
Release: 0

Summary: Zebra Remote Procedure Call
Group: Applications/Internet
License: GPL
Source0: %{name}-%{version}.tar.gz
Source1: zrpcd.conf
Source2: zrpcd.service

BuildRequires:  systemd-units

Requires: thrift zeromq glib2 c-capnproto capnproto quagga
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd
%description
ZRPC provides a Thrift API and handles RPC to configure Quagga framework.

%prep
%setup -q

%build

%configure

%install
mkdir -p %{buildroot}%{_sysconfdir}
mkdir -p %{buildroot}%{_unitdir}
install %{SOURCE1} %{buildroot}%{_sysconfdir}/zrpcd.conf
install -p -D -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/zrpcd.service
%make_install

%post
%systemd_post zrpcd.service

%preun
%systemd_preun zrpcd.service

%postun
%systemd_postun_with_restart zrpcd.service

%files
%defattr(-,root,root)
%{_sbindir}/zrpcd
%{_includedir}/%name/zrpc_global.h
%{_includedir}/%name/zrpc_os_wrapper.h
%{_sysconfdir}/zrpcd.conf
%{_unitdir}/zrpcd.service
