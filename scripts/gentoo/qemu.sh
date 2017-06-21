#!/bin/bash

emerge sys-apps/dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
  exit 0
fi

echo "app-emulation/qemu-guest-agent ~amd64" > /etc/portage/package.accept_keywords/qemu
emerge app-emulation/qemu-guest-agent

rc-update add qemu-guest-agent default
rc-service qemu-guest-agent start
# systemctl enable qemu-ga-systemd.service
# systemctl start qemu-ga-systemd.service
