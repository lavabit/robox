#!/bin/bash -eux

if [ ! -d /media/BaseOS/ ] || [ ! -d /media/AppStream/ ]; then
  mount /dev/cdrom /media || (printf "\nFailed mount RHEL cdrom.\n"; exit 1)
fi

# Install memcached.
yum install --assumeyes libevent memcached

# Ensure memcached doesn't try to use IPv6.
if [ -f /etc/sysconfig/memcached ]; then
  sed -i "s/[,]\?\:\:1[,]\?//g" /etc/sysconfig/memcached
fi

# Setup memcached to start automatically.
systemctl start memcached.service && systemctl enable memcached.service
