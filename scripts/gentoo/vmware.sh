#!/bin/bash

emerge sys-apps/dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# echo "app-emulation/open-vm-tools ~amd64" > /etc/portage/package.accept_keywords/vmware
USE="python_targets_python2_7 python_targets_python3_6" emerge --ask=n --autounmask-continue=y app-emulation/open-vm-tools

# Perform any configuration file updates.
etc-update --automode -5

rc-update add vmware-tools default
rc-service vmware-tools start
# systemctl enable vmtoolsd.service
# systemctl start vmtoolsd.service

rm --force /root/linux.iso

# Rebuild the whole system so the VMWware drivers are supported properly.
emerge --deep --with-bdeps=y @system @world
