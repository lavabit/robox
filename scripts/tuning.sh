#!/bin/bash

# Configure tuned
tuned-adm profile virtual-guest

# Configure grub to wait just 1 second before booting
sed -i 's/^timeout=[0-9]\+$/timeout=1/' /boot/grub/grub.conf
