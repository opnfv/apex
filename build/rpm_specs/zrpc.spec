Name: zrpc
Version: 0.2.
Release: 0

Summary: Zebra Remote Procedure Call
Group: Applications/Internet
License: GPL
Source0: zrpcd-0.2.tar.gz
Requires: thrift zeromq glib2 capnproto quagga

%description
ZRPC provides a Thrift API and handles RPC to configure Quagga framework.

%install
rm -rf %{buildroot} && mkdir -p %{buildroot}
cd /home/packger/packager/<output> && find . \! -type d | cpio -o -H ustar -R 0:0 | tar -C %{buildroot} -x
find %{buildroot} -type f -o -type l|sed "s,%{buildroot},," > %{_builddir}/files
sed -ri "s/\.py$/\.py*/" %{_builddir}/files

%clean
rm -rf %{buildroot}

%pre
getent group quagga >/dev/null 2>&1 || groupadd -g 92 quagga >/dev/null 2>&1 || :
getent passwd quagga >/dev/null 2>&1 || useradd -u 92 -g 92 -M -r -s /sbin/nologin \
 -c "Quagga routing suite" -d /var/run/quagga quagga >/dev/null 2>&1 || :

%postun

%post

%preun

%files -f %{_builddir}/files
%defattr(-,root,root)
%dir %attr(750,quagga,quagga) /opt/quagga/var/run/quagga
%dir %attr(750,quagga,quagga) /opt/quagga/var/log/quagga
