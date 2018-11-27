#!/bin/bash -eux

# Ensure the pkg utilities are in the path.
export PATH="/usr/sbin/:/usr/pkg/bin/:$PATH"

# Dictate the package repository.
export PKG_PATH="ftp://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/8.0/All"

# Ensure dmideocode is available.
pkg_add dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

rm -f /root/freebsd.iso
