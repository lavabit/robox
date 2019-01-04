#!/bin/bash

error() {
  if [ $? -ne 0 ]; then
    printf "\n\nThe VirtualBox install failed...\n\n"

    # if [ -f /var/log/VBoxGuestAdditions.log ]; then
    #   printf "\n\n/var/log/VBoxGuestAdditions.log\n\n"
    #   cat /var/log/VBoxGuestAdditions.log
    # else
    #   printf "\n\nThe /var/log/VBoxGuestAdditions.log is missing...\n\n"
    # fi
    #
    # if [ -f /var/log/vboxadd-install.log ]; then
    #   printf "\n\n/var/log/vboxadd-install.log\n\n"
    #   cat /var/log/vboxadd-install.log
    # else
    #   printf "\n\nThe /var/log/vboxadd-install.log is missing...\n\n"
    # fi
    exit 1
  fi
}

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# Read in the version number.
VBOXVERSION=`cat /root/VBoxVersion.txt`

dnf install --assumeyes virtualbox-guest-additions; error

# # Experimental logic. Guessing it doesn't work yet because the RPM is dependent upon a repo specific kernel dependency.
# curl --location --output akmod-VirtualBox-5.2.20-1.fc29.x86_64.rpm "https://download1.rpmfusion.org/free/fedora/releases/29/Everything/x86_64/os/Packages/a/akmod-VirtualBox-5.2.20-1.fc29.x86_64.rpm"; error
# echo "0b898908a8cf8965f5931f3cdc01f231743e858319cd83419d54863973bb584b  akmod-VirtualBox-5.2.20-1.fc29.x86_64.rpm" | sha256sum --check; error
# dnf install --assumeyes akmod-VirtualBox-5.2.20-1.fc29.x86_64.rpm; error

# dnf install --assumeyes dkms binutils gcc make patch libgomp glibc-headers glibc-devel kernel-headers kernel-devel bzip2 kernel-headers kernel-devel kernel-cross-headers; error
#
# # The group vboxsf is needed for shared folder access.
# getent group vboxsf >/dev/null || groupadd --system vboxsf; error
# getent passwd vboxadd >/dev/null || useradd --system --gid bin --home-dir /var/run/vboxadd --shell /sbin/nologin vboxadd; error
#
# mkdir -p /mnt/virtualbox; error
# mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox; error
#
# # For some reason the vboxsf module fails the first time, but installs
# # successfully if we run the installer a second time.
# sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11 || sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11; error
# ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions; error
#
# umount /mnt/virtualbox; error
rm -rf /root/VBoxVersion.txt; error
rm -rf /root/VBoxGuestAdditions.iso; error
