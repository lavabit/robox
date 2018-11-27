#!/bin/bash -ux

# Ensure the pkg utilities are in the path.
export PATH="/usr/sbin/:/usr/pkg/bin/:$PATH"

# Dictate the package repository.
export PKG_PATH="ftp://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/8.0/All"

# Needed to check whether we're running atop Parallels.
pkg_add dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
    exit 0
fi

# Read in the version number.
PARALLELSVERSION=`cat /root/parallels-tools-version.txt`

mkdir -p /mnt/parallels/
mount -o loop /root/parallels-tools-other.iso /mnt/parallels/
# bash /mnt/parallels/install --install-unattended-with-deps
umount /mnt/parallels/
rmdir /mnt/parallels/

# Cleanup the guest additions.
rm -f /root/parallels-tools-other.iso
rm -f /root/parallels-tools-version.txt
