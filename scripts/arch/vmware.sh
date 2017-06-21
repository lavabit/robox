#!/bin/bash

pacman --sync --noconfirm dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

pacman --sync --noconfirm open-vm-tools

systemctl enable vmtoolsd.service
systemctl enable vmware-vmblock-fuse.service
systemctl start vmtoolsd.service
systemctl start vmware-vmblock-fuse.service
