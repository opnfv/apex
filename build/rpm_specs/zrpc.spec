Name: zrpcd
Version: 0.2
Release: 0

Summary: Zebra Remote Procedure Call
Group: Applications/Internet
License: GPL
Source0: %{name}-%{version}.tar.gz
Requires: thrift zeromq glib2 c-capnproto capnproto quagga

%description
ZRPC provides a Thrift API and handles RPC to configure Quagga framework.

%prep
%setup -q

%build

%configure

%install
%make_install

%files
%defattr(-,root,root)
%{_sbindir}/zrpcd
%{_includedir}/%name/zrpc_global.h
%{_includedir}/%name/zrpc_os_wrapper.h
