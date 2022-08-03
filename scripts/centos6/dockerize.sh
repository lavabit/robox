#!/bin/bash

# Cleanup.
rpm -Va --nofiles --nodigest
yum clean all

# Stop services to avoid tarring sockets.
service abrt stop
service dbus stop
service mysqld stop
service postfix stop

#LANG="en_US"
#echo "%_install_lang $LANG" > /etc/rpm/macros.image-language-conf

awk '(NF==0&&!done){print "override_install_langs='$LANG'\ntsflags=nodocs";done=1}{print}' \
    < /etc/yum.conf > /etc/yum.conf.new
mv /etc/yum.conf.new /etc/yum.conf
echo 'container' > /etc/yum/vars/infra

rm -f /usr/lib/locale/locale-archive

# Setup the login message instructions.
if [[ ! "$PACKER_BUILD_NAME" =~ ^generic-.*$ ]]; then
  printf "Magma Daemon Development Environment\nTo download and compile magma, just execute the magma-build.sh script.\n\n" > /etc/motd
fi

# Add a profile directive to send docker logins to the home directory.
printf "if [ \"\$PS1\" ]; then\n  cd \$HOME\nfi\n" > /etc/profile.d/home.sh

# Setup the locale, and arrogantly assume everyone lives in the US.
localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

rm -rf /var/cache/yum/*
rm -f /tmp/ks-script*
rm -rf /var/log/*
rm -rf /tmp/*

# Mark the docker box build time.
date --utc > /etc/docker_box_build_time

# Randomize the root password and then lock the root account.
dd if=/dev/urandom count=50 | md5sum | awk -F' ' '{print $1}' | passwd --stdin root
passwd --lock root

if [ -f /etc/machine-id ]; then
  truncate --size=0 /etc/machine-id
fi

# tar --create --numeric-owner --one-file-system --directory=/ --file=/tmp/$PACKER_BUILD_NAME.tar \
# --exclude=/tmp/$PACKER_BUILD_NAME.tar --exclude=/boot --exclude=/run/* --exclude=/var/spool/postfix/private/* .

# Exclude the extraction files from the tarball.
printf "/tmp/excludes\n" > /tmp/excludes
printf "/tmp/$PACKER_BUILD_NAME.tar\n" >> /tmp/excludes

# Exclude all of the special files from the tarball.
find -L $(ls -1 -d /* | grep -Ev "sys|dev|proc") -type b -print 1>>/tmp/excludes 2>/dev/null
find -L $(ls -1 -d /* | grep -Ev "sys|dev|proc") -type c -print 1>>/tmp/excludes 2>/dev/null
find -L $(ls -1 -d /* | grep -Ev "sys|dev|proc") -type p -print 1>>/tmp/excludes 2>/dev/null
find -L $(ls -1 -d /* | grep -Ev "sys|dev|proc") -type s -print 1>>/tmp/excludes 2>/dev/null
find /var/log/ -type f -print 1>>/tmp/excludes 2>/dev/null
find /lib/modules/ -mindepth 1 -print 1>>/tmp/excludes 2>/dev/null
find /usr/src/kernels/ -mindepth 1 -print 1>>/tmp/excludes 2>/dev/null
find /var/lib/yum/yumdb/ -mindepth 1 -print 1>>/tmp/excludes 2>/dev/null
find /etc/sysconfig/network-scripts/ -name "ifcfg-*" -print 1>>/tmp/excludes 2>/dev/null
find /tmp -type f -or -type d -print | grep --invert-match --extended-regexp "^/tmp/$|^/tmp$" >> /tmp/excludes

# Remove the files associated with these packages since containers don't need them.
PACKAGES=`rpm -q kernel kernel-devel kernel-headers kernel-tools kernel-tools-libs dhclient dhcp-libs dracut dracut-kernel grubby kmod grub2 kmod-libs dracut firewalld dbus-glib dbus-python ebtables gobject-introspection pygobject3-base python-decorator python-slip python-slip-dbus kpartx kernel-firmware device-mapper device-mapper-event device-mapper-event-libs device-mapper-libs device-mapper-persistent-data e2fsprogs-libs iptables iptables-ipv6  | grep --invert "not installed"`

# Manually exclude certain files/directories from the list.
rpm -q --list $PACKAGES | grep --invert "/usr/share/bash-completion/completions" | \
  grep --invert "/etc/profile.d" >> /tmp/excludes

# Remove the leading slash so the names match up with tar.
sed --in-place "s/^\///g" /tmp/excludes

# Tarball the filesystem.
tar --create --numeric-owner --preserve-permissions --one-file-system \
  --directory=/ --file=/tmp/$PACKER_BUILD_NAME.tar --exclude=/etc/firewalld \
  --exclude=/boot --exclude=/proc --exclude=/lost+found --exclude=/mnt --exclude=/sys \
  --exclude=/var/run/udev --exclude=/run/udev -X /tmp/excludes /

if [ $? != 0 ] || [ ! -f /tmp/$PACKER_BUILD_NAME.tar ]; then
  printf "\n\nTarball generation failed.\n\n"
  printf "locked\n" | passwd --stdin root
  passwd --unlock root
  exit 1
else
  printf "\nTarball generation succeeded.\n"
fi

printf "locked\n" | passwd --stdin root
passwd --unlock root

dhclient
