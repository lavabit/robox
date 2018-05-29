#!/bin/bash -ux

# Needed to check whether we're running atop Parallels.
export DEBIAN_FRONTEND=noninteractive
apt-get --assume-yes install dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
    exit 0
fi

# Read in the version number.
PARALLELSVERSION=`cat /root/parallels-tools-version.txt`

# Cleanup the guest additions.
rm --force /root/parallels-tools-linux.iso
rm --force /root/parallels-tools-version.txt
