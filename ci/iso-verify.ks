# poweroff on success
poweroff

# Do not configure the X Window System
skipx
# System timezone
timezone US/Eastern --isUtc
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
autopart --type=lvm
# Partition clearing information
clearpart --all --initlabel --drives=vda

%packages
@apex-opendaylight
@base
@core
@virtualization-hypervisor
@virtualization-tools
chrony
kexec-tools

%end

%addon com_redhat_kdump --disable

%end

%anaconda
pwpolicy root --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy luks --minlen=6 --minquality=50 --notstrict --nochanges --notempty
%end
 
#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512
# Use CDROM installation media
cdrom
# Use text mode install
text
# Run the Setup Agent on first boot
firstboot --disable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts=''
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=dhcp --device=eth0 --onboot=off --ipv6=auto --no-activate
network  --hostname=localhost.localdomain

# Root password
rootpw --iscrypted $6$l4m1GNdyJ/.EP40T$2Nn99xwbJexsqqYqbgWCUivSIqJTOTTNuxmli6TM9.3uom5eiIZDPQ3UZ6gVYi0ir2px4z7e2DnccmoV/EXNB/
# System services
services --enabled="chronyd"
