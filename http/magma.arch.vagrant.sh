#!/bin/bash -eux

if [ -e /dev/vda ]; then
  device=/dev/vda
elif [ -e /dev/sda ]; then
  device=/dev/sda
else
  echo "ERROR: There is no disk available for installation" >&2
  exit 1
fi
export device

# memory_size_in_kilobytes=$(free | awk '/^Mem:/ { print $2 }')
# swap_size_in_kilobytes=$((memory_size_in_kilobytes * 2))
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
printf "Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch\n" > /tmp/mirrolist.50

curl -fsS https://www.archlinux.org/mirrorlist/?country=all > /tmp/mirrolist
grep '^#Server' /tmp/mirrolist | grep "https" | sort -R | head -n 50 | sed 's/^#//' >> /tmp/mirrolist.50
rankmirrors -v /tmp/mirrolist.50 | tee /etc/pacman.d/mirrorlist
pacstrap /mnt base grub openssh sudo

swapon "${device}1"
genfstab -p /mnt >> /mnt/etc/fstab
swapoff "${device}1"

arch-chroot /mnt /bin/bash
