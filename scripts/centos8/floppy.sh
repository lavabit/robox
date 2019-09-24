#!/bin/bash -eux

printf 'blacklist floppy\n' > /etc/modprobe.d/floppy.conf
chcon system_u:object_r:modules_conf_t:s0 /etc/modprobe.d/floppy.conf
mkinitrd --force /boot/initramfs-$(uname -r).img $(uname -r)

