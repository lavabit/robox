#!/bin/bash -eux

# Remove the hard coded kernel VGA resolution needed to workaround Hyper-V bugs during installation.
sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)vga=normal nomodeset text\(.*\)"$/GRUB_CMDLINE_LINUX="\1\2"/g' /etc/default/grub

# On UEFI systems.
if [ -f /boot/efi/EFI/fedora/grub.cfg ]; then
  grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg

elif [ -f /boot/efi/EFI/centos/grub.cfg ]; then
  grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg

elif [ -f /boot/efi/EFI/redhat/grub.cfg ]; then
  grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg

# On BIOS systems.
else
  grub2-mkconfig -o /boot/grub2/grub.cfg
fi
