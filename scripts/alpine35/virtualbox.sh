#!/bin/bash -eux

# Ensure dmidecode is available.
apk add dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# Add the community repository.
printf "@community https://mirror.leaseweb.com/alpine/v3.5/community\n" >> /etc/apk/repositories

# Add the testing repository (which isn't available over HTTPS).
printf "@testing http://nl.alpinelinux.org/alpine/edge/testing\n" >> /etc/apk/repositories

# Add the primary site.
printf "@edge http://nl.alpinelinux.org/alpine/edge/main/\n" >> /etc/apk/repositories

# Update the APK cache.
apk update --no-cache

# Install the VirtualBox kernel modules for guest services.
apk add linux-hardened@edge virtualbox-additions-hardened@testing

# Autoload the virtualbox kernel modules.
echo vboxpci >> /etc/modules
echo vboxdrv >> /etc/modules
echo vboxnetflt >> /etc/modules

# Read in the version number.
# export VBOXVERSION=`cat /root/VBoxVersion.txt`
#
# export DEBIAN_FRONTEND=noninteractive
# apt-get --assume-yes install dkms build-essential module-assistant linux-headers-$(uname -r)
#
# mkdir -p /mnt/virtualbox
# mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox
#
# /mnt/virtualbox/VBoxLinuxAdditions.run --nox11
# ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions
#
# umount /mnt/virtualbox
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso

# Boosts the available entropy which allows magma to start faster.
apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start
