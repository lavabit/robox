#!/bin/bash

# Configure tuned
yum --quiet --assumeyes install tuned
tuned-adm profile virtual-guest
chkconfig tuned on

# Configure grub to wait just 1 second before booting
sed -i 's/^timeout=[0-9]\+$/timeout=1/' /boot/grub/grub.conf
