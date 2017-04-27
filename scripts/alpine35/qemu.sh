#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nqemu addons failed to install...\n\n";
                exit 1
        fi
}


# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
    exit 0
fi

# Install the QEMU using Yum.
printf "Installing the QEMU Tools.\n"

# Install the QEMU guest tools.
apk add --force qemu-guest-agent; error

# Autostart the open-vm-tools.
rc-update add qemu-guest-agent default && rc-service qemu-guest-agent start; error

# Boosts the available entropy which allows magma to start faster.
apk add --force haveged; error

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start; error
