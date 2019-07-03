#!/bin/bash -eux

# Disable the floppy module.
printf 'blacklist floppy\n' > /etc/modprobe.d/60-floppy.conf
mkinitrd
