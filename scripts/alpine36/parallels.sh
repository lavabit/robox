#!/bin/bash -ux

# Needed to check whether we're running atop Parallels.
apk add dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
    exit 0
fi

# Read in the version number.
PARALLELSVERSION=`cat /root/parallels-tools-version.txt`

# The mount command syntax doesn't work on Alpine.
# mkdir -p /mnt/parallels/
# mount -o loop /root/parallels-tools-linux.iso /mnt/parallels/
# bash /mnt/parallels/install --install-unattended-with-deps
# umount /mnt/parallels/
# rmdir /mnt/parallels/

# Cleanup the guest additions.
rm -f /root/parallels-tools-linux.iso
rm -f /root/parallels-tools-version.txt
