#!/usr/bin/env bash
##############################################################################
# Copyright (c) 2015 Tim Rozet (Red Hat), Dan Radez (Red Hat) and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################



##Copy over the glance images and instackenv json file
##params: none
function configure_undercloud {

  # configure undercloud on Undercloud VM
  echo "Running undercloud installation and configuration."
  echo "Logging undercloud installation to stack@undercloud:/home/stack/apex-undercloud-install.log"
  ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
set -e

if [[ -n "${deploy_options_array['ceph_device']}" ]]; then
    sed -i '/ExtraConfig/a\\    ceph::profile::params::osds: {\\x27${deploy_options_array['ceph_device']}\\x27: {}}' ${ENV_FILE}
fi

sudo sed -i '/CephClusterFSID:/c\\  CephClusterFSID: \\x27$(cat /proc/sys/kernel/random/uuid)\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml
sudo sed -i '/CephMonKey:/c\\  CephMonKey: \\x27'"\$(ceph-authtool --gen-print-key)"'\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml
sudo sed -i '/CephAdminKey:/c\\  CephAdminKey: \\x27'"\$(ceph-authtool --gen-print-key)"'\\x27' /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml


if [ "\$(uname -i)" == 'aarch64' ]; then
sudo yum -y reinstall grub2-efi shim
sudo cp /boot/efi/EFI/centos/grubaa64.efi /tftpboot/grubaa64.efi
sudo mkdir -p /tftpboot/EFI/centos
sudo tee /tftpboot/EFI/centos/grub.cfg > /dev/null << EOF
set default=master
set timeout=5
set hidden_timeout_quiet=false

menuentry "master"  {
configfile /tftpboot/\\\$net_default_ip.conf
}
EOF
sudo chmod 644 /tftpboot/EFI/centos/grub.cfg
sudo openstack-config --set /etc/ironic/ironic.conf pxe uefi_pxe_config_template \\\$pybasedir/drivers/modules/pxe_grub_config.template
sudo openstack-config --set /etc/ironic/ironic.conf pxe uefi_pxe_bootfile_name grubaa64.efi
sudo service openstack-ironic-conductor restart
sudo sed -i 's/linuxefi/linux/g' /usr/lib/python2.7/site-packages/ironic/drivers/modules/pxe_grub_config.template
sudo sed -i 's/initrdefi/initrd/g' /usr/lib/python2.7/site-packages/ironic/drivers/modules/pxe_grub_config.template
echo '' | sudo tee --append /tftpboot/map-file > /dev/null
echo 'r ^/EFI/centos/grub.cfg-(.*) /tftpboot/pxelinux.cfg/\\1' | sudo tee --append /tftpboot/map-file > /dev/null
sudo service xinetd restart
fi
EOI


}
