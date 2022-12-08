#!/bin/bash -eux

# Remove the hard coded kernel VGA resolution needed to workaround Hyper-V bugs during installation.
sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)vga=792\(.*\)"$/GRUB_CMDLINE_LINUX="\1\2"/g' /etc/default/grub

# For UEFI systems.
[ -f /etc/grub2-efi.cfg  ] && grub2-mkconfig -o /etc/grub2-efi.cfg 
# For BIOS systems.
[ -f /etc/grub2.cfg ] && grub2-mkconfig -o /etc/grub2.cfg
