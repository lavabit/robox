#!/bin/bash -eux

# Needed to check whether we're running in VirtualBox.
yum --assumeyes install dmidecode

# Bail if we are not running inside VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# Read in the version number.
VBOXVERSION=`cat /root/VBoxVersion.txt`

# Packages required to build the guest additions.
yum --assumeyes install gcc make perl dkms bzip2 kernel-devel kernel-headers autoconf automake binutils bison flex gcc-c++ gettext libtool make patch pkgconfig

mkdir -p /mnt/virtualbox
mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox

sh /mnt/virtualbox/VBoxLinuxAdditions.run
ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions

umount /mnt/virtualbox
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso
