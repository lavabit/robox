#!/bin/bash

emerge sys-apps/dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

USE="-X -resolutionkms icu pam ssl fuse vgauth xml-security-c grabbitmqproxy python_targets_python3_6" emerge --ask=n --autounmask-write=y --autounmask-continue=y app-emulation/open-vm-tools =openssh-7.5_p1-r4

# Perform any configuration file updates.
etc-update --automode -5

rc-update add vmware-tools default
rc-service vmware-tools start
# systemctl enable vmtoolsd.service
# systemctl start vmtoolsd.service

rm --force /root/linux.iso

