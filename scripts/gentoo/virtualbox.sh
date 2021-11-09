#!/bin/bash

emerge sys-apps/dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install VirtualBox from portage
# echo "app-emulation/virtualbox-guest-additions ~amd64" > /etc/portage/package.accept_keywords/virtualbox
USE="-X python_targets_python3_6" emerge --ask=n --autounmask-write=y --autounmask-continue=y app-emulation/virtualbox-guest-additions

# Perform any configuration file updates.
etc-update --automode -5

# rc-update add virtualbox-guest-additions default
# rc-service virtualbox-guest-additions start
systemctl enable virtualbox-guest-additions.service
systemctl start virtualbox-guest-additions.service

# Cleanup the guest additions disc.
rm --force VBoxVersion.txt
rm --force VBoxGuestAdditions.iso
