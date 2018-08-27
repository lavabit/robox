#!/bin/bash -eux

# Remove the hard coded kernel VGA resolution needed to workaround Hyper-V bugs during installation.
sed -i "s/kernel \(.*\)vga=792\(.*\)/kernel \1\2/g" /etc/grub.conf

# In thoery the /etc/grub.conf file is linked to the approriate grub.conf file
# but just in case, we run sed against the config files on the boot partition.
if [ -f /boot/efi/EFI/fedora/grub.cfg ]; then
  sed -i "s/kernel \(.*\)vga=792\(.*\)/kernel \1\2/g" /boot/efi/EFI/fedora/grub.conf

elif [ -f /boot/efi/EFI/centos/grub.cfg ]; then
  sed -i "s/kernel \(.*\)vga=792\(.*\)/kernelQ \1\2/g" /boot/efi/EFI/centos/grub.conf

elif [ -f /boot/efi/EFI/redhat/grub.cfg ]; then
  sed -i "s/kernel \(.*\)vga=792\(.*\)/kernel \1\2/g" /boot/efi/EFI/redhat/grub.conf

else
  sed -i "s/kernel \(.*\)vga=792\(.*\)/kernel \1\2/g" /boot/grub/grub.conf
fi
