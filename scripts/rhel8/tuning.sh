#!/bin/bash

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -d /media/BaseOS/ ] || [ ! -d /media/AppStream/ ]; then
  mount /dev/cdrom /media || (printf "\nFailed mount RHEL cdrom.\n"; exit 1)
fi

dnf --assumeyes install dmidecode

# Configure tuned
dnf --assumeyes install tuned
systemctl enable tuned
systemctl start tuned

# Set the profile to virtual guest.
tuned-adm profile virtual-guest

# Configure grub to wait just 1 second before booting
sed -i -e 's/^GRUB_TIMEOUT=[0-9]\+$/GRUB_TIMEOUT=1/' /etc/default/grub
# For UEFI systems.
[ -f /etc/grub2-efi.cfg  ] && grub2-mkconfig -o /etc/grub2-efi.cfg 
# For BIOS systems.
[ -f /etc/grub2.cfg ] && grub2-mkconfig -o /etc/grub2.cfg
