#!/bin/bash -ux

# Needed to check whether we're running atop Parallels.
pkg_add -I dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
    exit 0
fi

# Read in the version number.
PARALLELSVERSION=`cat /root/parallels-tools-version.txt`

# Cleanup the guest additions.
rm -f /root/parallels-tools-other.iso
rm -f /root/parallels-tools-version.txt
