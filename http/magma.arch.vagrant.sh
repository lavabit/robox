#!/bin/bash -eux

if [ -e /dev/vda ]; then
  device=/dev/vda
elif [ -e /dev/sda ]; then
  device=/dev/sda
else
  echo "ERROR: There is no disk available for installation." >&2
  exit 1
fi
export device

sfdisk "$device" <<EOF
label: dos
size=4096MiB,                      type=82
                                   type=83, bootable
EOF
mkswap "${device}1"
mkfs.ext4 "${device}2"
mount "${device}2" /mnt

# Ensure the kernel.org mirror is always listed, so things work, even when the archlinux
# website goes offline.
printf "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch\n" > /etc/pacman.d/mirrorlist

curl -fsS "https://www.archlinux.org/mirrorlist/?country=all" > /tmp/mirrolist
grep '^#Server' /tmp/mirrolist | grep "https" | sort -R | head -n 5 | sed 's/^#//' >> /etc/pacman.d/mirrorlist
pacstrap /mnt base grub bash sudo linux dhcpcd mkinitcpio openssh

swapon "${device}1"
genfstab -p /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash
[ -f /mnt/etc/fstab.pacnew ] && rm -f /mnt/etc/fstab.pacnew
swapoff "${device}1"
