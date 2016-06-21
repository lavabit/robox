#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nqemu addons failed to install...\n\n";
                exit 1
        fi
}


# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "KVM" ]]; then
    exit 0
fi

# Install the QEMU using Yum.
printf "\n\nInstalling the QEMU Tools.\n"

yum --assumeyes install qemu-guest-agent; error
