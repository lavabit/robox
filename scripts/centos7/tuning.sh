#!/bin/bash

# Configure tuned
yum --quiet --assumeyes install tuned
tuned-adm profile virtual-guest
systemctl enable tuned

# Configure grub to wait just 1 second before booting
sed -i -e 's/^GRUB_TIMEOUT=[0-9]\+$/GRUB_TIMEOUT=1/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
