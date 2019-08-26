bash -eux

if [ -h /etc/localtime ] && [ -f /usr/share/zoneinfo/UTC ]; then
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi
