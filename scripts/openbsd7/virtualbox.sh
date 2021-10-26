#!/bin/bash -eux

# Ensure dmideocode is available.
pkg_add -I dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso
