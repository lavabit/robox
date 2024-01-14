#!/bin/bash -x

emerge sys-apps/dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
  exit 0
fi

# echo "app-emulation/qemu-guest-agent ~amd64" > /etc/portage/package.accept_keywords/qemu
if [ "$(uname -m)" == "aarch64" ]; then
env ACCEPT_KEYWORDS="*" emerge --ask=n --autounmask-write=y --autounmask-continue=y app-emulation/qemu-guest-agent
else
emerge --ask=n --autounmask-write=y --autounmask-continue=y app-emulation/qemu-guest-agent
fi

# Perform any configuration file updates.
etc-update --automode -5

if [ "$(which rc-update 2>/dev/null)" ]; then
  rc-update add qemu-guest-agent default
  rc-service qemu-guest-agent start
else
  systemctl enable qemu-ga-systemd.service
  systemctl start qemu-ga-systemd.service
fi
