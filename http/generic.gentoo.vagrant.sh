#!/bin/bash -xe

echo 'Preparing Filesystem to Install Gentoo'

echo 'Partitioning Filesystems'
declare -i current=1
parted -a opt -s /dev/sda -- "mklabel gpt"
parted -a opt -s /dev/sda -- "mkpart BIOS ext4       $(( current ))  $(( current += 128   ))m"
parted -a opt -s /dev/sda -- "mkpart BOOT ext4       $(( current ))  $(( current += 256   ))m"
parted -a opt -s /dev/sda -- "mkpart SWAP linux-swap $(( current ))m $(( current += 4096  ))m"
parted -a opt -s /dev/sda -- "mkpart ROOT ext4       $(( current ))m -1"
parted -a opt -s /dev/sda -- "set 1 bios_grub on"
parted -a opt -s /dev/sda -- "set 2 boot on"

echo 'Formatting Filesystems'
echo /dev/sda[0-9]* | xargs -n1 -- mkfs -t ext4

echo 'Mounting Filesystems in /mnt/gentoo'
mkswap /dev/sda3
swapon /dev/sda3
mount /dev/sda4 /mnt/gentoo/
mkdir -p /mnt/gentoo/{boot,var,usr,tmp,home}
mount /dev/sda2 /mnt/gentoo/boot
mkdir -p /mnt/gentoo/boot/grub

cd /mnt/gentoo

# Download the current-stage3-amd64-nomultilib and the portage tarballs, unpack them, and then delete the archive files.
echo 'Downloading Tarballs'
tarball=$(wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-nomultilib/ -O - | grep -o -e "stage3-amd64-nomultilib-\w*.tar.bz2" | uniq)
wget --tries=5 -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-nomultilib/$tarball || exit 1
wget --tries=5 -q https://mirrors.kernel.org/gentoo/snapshots/portage-latest.tar.bz2 || exit 1

echo 'Extracting Gentoo Tarball'
tar xjpf $tarball && rm -f $tarball

echo 'Extracting Portage Tarball'
tar xjpf portage-latest.tar.bz2 -C '/mnt/gentoo/usr' && rm -f portage-latest.tar.bz2

# Copy the resolv config and rebind the dynamic system directories.
mount -t proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
cp /etc/resolv.conf /mnt/gentoo/etc

# Execute the chroot script.
chroot /mnt/gentoo /bin/bash < /root/generic.gentoo.vagrant.chroot.sh

# And then reboot.
echo "Chroot finished, ready to restart."
shutdown -r -t 15
umount --lazy /mnt/gentoo/{proc,sys,dev,boot,}
umount --lazy --detach-loop /dev/sr0
eject /dev/cdrom
reboot
