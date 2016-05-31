#!/bin/bash

# Bail if we are not running inside VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "\n\nInstalling the Virtual Box Tools.\n"

mkdir -p /mnt/virtualbox
mount -o loop /root/VBoxGuest*.iso /mnt/virtualbox

sh /mnt/virtualbox/VBoxLinuxAdditions.run
ln -s /opt/VBoxGuestAdditions-*/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions

umount /mnt/virtualbox
rm -rf /root/VBoxGuest*.iso
