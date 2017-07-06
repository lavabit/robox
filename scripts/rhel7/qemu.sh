#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nqemu addons failed to install...\n\n";
                exit 1
        fi
}

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -f /media/media.repo ]; then
  mount /dev/cdrom /media; error
fi

yum --assumeyes install dmidecode; error

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
    exit 0
fi

# Install the QEMU using Yum.
printf "Installing the QEMU Tools.\n"

yum --quiet --assumeyes install qemu-guest-agent; error
