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

apt-get --assume-yes --ignore-missing install qemu-guest-agent; error

# For some reason the VMWare tools are installed on QEMU guest images.
systemctl disable open-vm-tools.service

# Boosts the available entropy which allows magma to start faster.
apt-get --assume-yes --ignore-missing install haveged; error

# Autostart the haveged daemon.
systemctl enable haveged.service
