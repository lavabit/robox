#!/bin/bash

pacman --sync --noconfirm dmidecode

# Bail if we are not running inside VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

pacman --sync --noconfirm virtualbox-guest-utils-nox

systemctl enable vboxservice.service
systemctl start vboxservice.service
