#!/bin/bash

pacman --sync --noconfirm dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
  exit 0
fi

pacman --sync --noconfirm --refresh qemu-guest-agent

systemctl enable qemu-ga.service
systemctl start qemu-ga.service
