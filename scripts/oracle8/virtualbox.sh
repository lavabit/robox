#!/bin/bash -eux

error() {
  if [ $? -ne 0 ]; then
    printf "\n\nThe VirtualBox install failed...\n\n"

    if [ -f /var/log/VBoxGuestAdditions.log ]; then
      printf "\n\n/var/log/VBoxGuestAdditions.log\n\n"
      cat /var/log/VBoxGuestAdditions.log
    else
      printf "\n\nThe /var/log/VBoxGuestAdditions.log is missing...\n\n"
    fi

    if [ -f /var/log/vboxadd-install.log ]; then
      printf "\n\n/var/log/vboxadd-install.log\n\n"
      cat /var/log/vboxadd-install.log
    else
      printf "\n\nThe /var/log/vboxadd-install.log is missing...\n\n"
    fi

    exit 1
  fi
}

# Needed to check whether we're running atop VirtualBox.
yum --assumeyes install dmidecode; error

# The group vboxsf is needed for shared folder access.
getent group vboxsf >/dev/null || groupadd --system vboxsf; error
getent passwd vboxadd >/dev/null || useradd --system --gid bin --home-dir /var/run/vboxadd --shell /sbin/nologin vboxadd; error

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# Read in the version number.
VBOXVERSION=`cat /root/VBoxVersion.txt`

# Packages required to build the guest additions.
# yum --assumeyes install gcc make perl dkms bzip2 kernel-tools kernel-headers kernel-devel kernel-uek-devel autoconf automake binutils bison flex gcc-c++ gettext libtool make patch pkgconfig; error
yum --assumeyes install gcc make perl bzip2 kernel-tools kernel-headers kernel-devel autoconf automake binutils bison flex gcc-c++ gettext libtool make patch pkgconfig; error

mkdir -p /mnt/virtualbox; error
mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox; error

# For some reason the vboxsf module fails the first time, but installs
# successfully if we run the installer a second time.
sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11 || sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11; error
ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions; error

umount /mnt/virtualbox; error
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso
