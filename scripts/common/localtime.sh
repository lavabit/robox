bash -eux

if [ $(command -v timedatectl) ]; then 
  timedatectl set-timezone UTC
elif [ -f /etc/sysconfig/clock ] && [ $(command -v tzdata-update) ]; then
  printf "ZONE=\"UTC\"\n" > /etc/sysconfig/clock
  tzdata-update
elif [ -f /etc/localtime ] && [ -f /usr/share/zoneinfo/UTC ]; then
  cp -f /usr/share/zoneinfo/UTC /etc/localtime
elif [ -h /etc/localtime ] && [ -f /usr/share/zoneinfo/UTC ]; then
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi
