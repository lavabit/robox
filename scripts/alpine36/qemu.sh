#!/bin/bash -eux

# Ensure dmidecode is available.
apk add dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
    exit 0
fi

# Install the QEMU using Yum.
printf "Installing the QEMU Tools.\n"

# Install the QEMU guest tools.
apk add qemu-guest-agent

# Autostart the open-vm-tools.
rc-update add qemu-guest-agent default && rc-service qemu-guest-agent start

# Boosts the available entropy which allows magma to start faster.
apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start
