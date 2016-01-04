#!/bin/sh
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -e

echo "Building OpenDaylight SFC Overcloud disk image"

################################################
#####    Adding SFC+OpenDaylight overcloud #####
################################################

#copy opendaylight overcloud full to isolate odl-sfc
cp -f images/overcloud-full-opendaylight.qcow2 images/overcloud-full-opendaylight-sfc_build.qcow2

# work around for XFS grow bug
# http://xfs.org/index.php/XFS_FAQ#Q:_Why_do_I_receive_No_space_left_on_device_after_xfs_growfs.3F
cat > /tmp/xfs-grow-remount-fix.service << EOF
[Unit]
Description=XFS Grow Bug Remount
After=network.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo 'XFS Grow Bug Remount Sleeping 180s' && sleep 180 && echo 'XFS Grow Bug Remounting Now' && mount -o remount,inode64 /"
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF


# kernel is patched with patch from this post
# http://xfs.org/index.php/XFS_FAQ#Q:_Why_do_I_receive_No_space_left_on_device_after_xfs_growfs.3F
LIBGUESTFS_BACKEND=direct virt-customize \
    --upload "/tmp/xfs-grow-remount-fix.service:/etc/systemd/system/xfs-grow-remount-fix.service" \
    --run-command "chmod 664 /etc/systemd/system/xfs-grow-remount-fix.service" \
    --run-command "systemctl enable xfs-grow-remount-fix.service" \
    --install 'https://radez.fedorapeople.org/kernel-ml-3.13.7-1.el7.centos.x86_64.rpm' \
    --run-command 'grub2-set-default "\$(grep -P \"submenu|^menuentry\" /boot/grub2/grub.cfg | cut -d \"\\x27\" | head -n 1)"' \
    --install 'https://radez.fedorapeople.org/openvswitch-kmod-2.3.90-1.el7.centos.x86_64.rpm' \
    --run-command 'yum downgrade -y https://radez.fedorapeople.org/openvswitch-2.3.90-1.x86_64.rpm' \
    --run-command 'rm -f /lib/modules/3.13.7-1.el7.centos.x86_64/kernel/net/openvswitch/openvswitch.ko' \
    --run-command 'ln -s /lib/modules/3.13.7-1.el7.centos.x86_64/kernel/extra/openvswitch/openvswitch.ko /lib/modules/3.13.7-1.el7.centos.x86_64/kernel/net/openvswitch/openvswitch.ko' \
    -a images/overcloud-full-opendaylight-sfc_build.qcow2
mv images/overcloud-full-opendaylight-sfc_build.qcow2 images/overcloud-full-opendaylight-sfc.qcow2
