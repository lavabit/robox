#!/bin/bash -eux

# If localtime is a regular file then the timedatectl command will fail.
if [ -f /etc/localtime ] && [ "$(command -v timedatectl)" ]; then
  rm -f /etc/localtime
  timedatectl set-timezone UTC
# Run the timedatectl command without removing a file.
elif [ "$(command -v timedatectl)" ]; then
  timedatectl set-timezone UTC

# Handle older distros which use sysconfig and the tzdata-update command.
elif [ -f /etc/sysconfig/clock ] && [ "$(command -v tzdata-update)" ]; then
  printf "ZONE=\"UTC\"\n" > /etc/sysconfig/clock
  tzdata-update

# Logic of last resort.
elif [ -h /etc/localtime ] && [ -f /usr/share/zoneinfo/UTC ]; then
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
elif [ -f /etc/localtime ] && [ -f /usr/share/zoneinfo/UTC ]; then
  cp -f /usr/share/zoneinfo/UTC /etc/localtime
fi
