#!/bin/bash

# Configure tuned
yum --quiet --assumeyes install tuned
chkconfig tuned on
service tuned start

# Set the profile to virtual guest.
tuned-adm profile virtual-guest

# Configure grub to wait just 1 second before booting
sed -i 's/^timeout=[0-9]\+$/timeout=1/' /boot/grub/grub.conf
