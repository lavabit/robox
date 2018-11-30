#!/bin/bash -eux

# Ensure the pkg utilities are in the path.
export PATH="/usr/sbin/:/usr/pkg/bin/:$PATH"

# Dictate the package repository.
export PKG_PATH="ftp://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/8.0/All"

# Ensure dmideocode is available.
pkg_add dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `/usr/pkg/sbin/dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso
