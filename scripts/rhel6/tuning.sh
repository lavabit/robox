#!/bin/bash

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -f /media/media.repo ]; then
  mount /dev/cdrom /media; error
fi

# Configure tuned
yum --assumeyes install tuned
chkconfig tuned on
service tuned start

# Set the profile to virtual guest.
tuned-adm profile virtual-guest

# Configure grub to wait just 1 second before booting
sed -i 's/^timeout=[0-9]\+$/timeout=1/' /boot/grub/grub.conf
