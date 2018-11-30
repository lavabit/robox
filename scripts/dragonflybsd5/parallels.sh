#!/bin/bash -ux

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Needed to check whether we're running atop Parallels.
pkg-static install --yes dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
    exit 0
fi

# Install the DragonFlyBSD package with the Parallels guest tools.
pkg-static install --yes parallels-tools

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
