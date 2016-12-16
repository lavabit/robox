#!/bin/bash
# Post configure tasks for Docker

# remove stuff we don't need that anaconda insists on
# kernel needs to be removed by rpm, because of grubby
rpm -e kernel

rpm -e --nodeps bind-libs bind-libs-lite dhclient dhcp-common dhcp-libs \
  dracut-network e2fsprogs e2fsprogs-libs ebtables ethtool file \
  firewalld freetype gettext gettext-libs groff-base grub2 grub2-tools \
  grubby initscripts iproute iptables kexec-tools libcroco libgomp \
  libmnl libnetfilter_conntrack libnfnetlink libselinux-python lzo \
  libunistring os-prober python-decorator python-slip python-slip-dbus \
  snappy sysvinit-tools which linux-firmware

rpm -Va --nofiles --nodigest
yum clean all

# Stop services to avoid tarring sockets.
systemctl stop abrt
systemctl stop dbus
systemctl stop mysqld
systemctl stop postfix

# Clean up unused directories.
rm -rf /boot
rm -rf /etc/firewalld

awk '(NF==0&&!done){print "override_install_langs='$LANG'\ntsflags=nodocs";done=1}{print}' \
    < /etc/yum.conf > /etc/yum.conf.new
mv /etc/yum.conf.new /etc/yum.conf
echo 'container' > /etc/yum/vars/infra

rm -f /usr/lib/locale/locale-archive

# Setup the locale properly - arrogantly assume everyone lives in the US.
localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

rm -rf /var/cache/yum/*
rm -f /tmp/ks-script*
rm -rf /var/log/*
rm -rf /tmp/*
rm -rf /etc/sysconfig/network-scripts/ifcfg-*

# Fix /run/lock breakage since it's not tmpfs in docker
umount /run
systemd-tmpfiles --create --boot

# Make sure login works
rm /var/run/nologin

# Mark the docker box build time.
date --utc > /etc/docker_box_build_time

:> /etc/machine-id

tar --create --numeric-owner --one-file-system --directory=/ --exclude=/tmp/magma-docker.tar --file=/tmp/magma-docker.tar .
