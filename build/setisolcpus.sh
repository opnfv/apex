if [ "$2" != "" ]; then
  GRUBCONF=$2
else 
  GRUBCONF='/boot/grub/grub.conf'
fi

if [ "$1" != "" ]; then
  echo "Setting isolcpus=$1 in $GRUBCONF"
  KLINE=$(grep kernel $GRUBCONF)
  if [ "$KLINE" == "" ]; then
    echo "No kernel line found in grub.conf, exiting."
    exit 1
  fi
  sed -i "s#\skernel .*#$KLINE isolcpus=$1#g" $GRUBCONF
  exit 0
else
  echo "No isolcpus parameter provided, not modifying grub.conf"
  exit 1
fi
