#!/bin/bash -eux

# Ensure dmideocode is available.
pkg_add -I dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
    exit 0
fi
