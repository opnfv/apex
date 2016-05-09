GRUBCONF='/boot/grub2/grub.conf'

if [ "$1" == "" ]; then
  echo "No kernel parameter name provided, not modifying grub.conf"
  exit 1
fi

if [ "$2" == "" ]; then
  echo "No kernel parameter value provided, not modifying grub.conf"
  exit 1
fi

echo "Setting $1=$2 in $GRUBCONF"
echo "GRUB_CMDLINE_LINUX=\"\$GRUB_CMDLINE_LINUX $1=$2\"" >> /etc/default/grub
grub2-mkconfig > $GRUBCONF
exit 0
