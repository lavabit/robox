#!/bin/bash

pacman --sync --noconfirm dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

pacman --sync --noconfirm virtualbox-guest-modules-arch virtualbox-guest-utils-nox

systemctl enable vboxservice.service
systemctl start vboxservice.service

rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso
