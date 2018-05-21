#!/bin/bash

emerge sys-apps/dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# echo "app-emulation/open-vm-tools ~amd64" > /etc/portage/package.accept_keywords/vmware
emerge --update --ask=n --autounmask-continue=y app-emulation/open-vm-tools

# Perform any configuration file updates.
etc-update --automode -5

rc-update add vmware-tools default
rc-service vmware-tools start
# systemctl enable vmtoolsd.service
# systemctl start vmtoolsd.service
