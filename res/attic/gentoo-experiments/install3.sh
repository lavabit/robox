#!/bin/bash

set -e
set -x

# disable blanking so we can look for problems on the VM console
setterm -blank 0 -powersave off

# This will have been written out by the typed boot command
export CONFIG_SERVER_URI=`cat /root/config_server_uri`

# Pipe some commands into fdisk to partition
# Works better than sfdisk as the size of the final partition is flexible
echo "Partitioning SDA"

fdisk /dev/sda <<EOT
n
p
1
+256M
n
p
2
+4G
n
p
3
t
2
82
w
EOT

# Create some filesystems and enable swap (which we'll want for the build, particularly when hv_balloon misbehaves)
echo "Creating filesystems"

mkfs.ext4 /dev/sda1
mkswap /dev/sda2
mkfs.ext4 /dev/sda3

swapon /dev/sda2

# Pull the latest stage3 and unpack into the new filesystem
echo "Unpacking stage 3"

mount /dev/sda3 /mnt/gentoo

mkdir -p /mnt/gentoo/boot
mount /dev/sda1 /mnt/gentoo/boot

curl -SsLl "http://sd.ai/gentoo.php?file=stage3" | tar xjp -C /mnt/gentoo --xattrs --numeric-owner

# modify the chroot with some custom settings
echo "Setting up chroot configuration"

# configure portage
cat >> /mnt/gentoo/etc/portage/make.conf <<EOT
MAKEOPTS="-j5"
EMERGE_DEFAULT_OPTS="--quiet-build --autounmask-continue"
EOT

# use systemd
sed -i 's/USE="/USE="systemd /' /mnt/gentoo/etc/portage/make.conf
sed -i 's/CFLAGS="-O2/CFLAGS="-s -Os/' /mnt/gentoo/etc/portage/make.conf
echo 'LDFLAGS="-s"' >> /mnt/gentoo/etc/portage/make.conf

# package-specific configuration and unmasks
mkdir -p /mnt/gentoo/etc/portage/package.accept_keywords
mkdir -p /mnt/gentoo/etc/portage/package.use
touch /mnt/gentoo/etc/portage/package.accept_keywords/zzz-autounmask
touch /mnt/gentoo/etc/portage/package.use/zzz-autounmask

echo "sys-kernel/gentoo-sources ~amd64" > /mnt/gentoo/etc/portage/package.accept_keywords/kernel
echo "sys-kernel/gentoo-sources symlink experimental" > /mnt/gentoo/etc/portage/package.use/kernel
echo "sys-boot/grub efiemu -fonts -nls -themes" > /mnt/gentoo/etc/portage/package.use/grub
echo "sys-apps/systemd nat" > /mnt/gentoo/etc/portage/package.use/systemd

# Locale and time
echo "Etc/UTC" > /mnt/gentoo/etc/timezone
cat > /mnt/gentoo/etc/locale.gen <<EOT
en_GB ISO-8859-1
en_GB.UTF-8 UTF-8
EOT

# Create an fstab
cat > /mnt/gentoo/etc/fstab <<EOT
/dev/sda1 /boot ext4 noauto,noatime    1 2
/dev/sda2 none  swap sw                0 0
/dev/sda3 /     ext4 noauto,noatime    0 1
EOT

# kernel config & friends
mkdir -p /mnt/gentoo/etc/{kernels,default}
wget ${CONFIG_SERVER_URI}/gentoo/genkernel.conf -O /mnt/gentoo/etc/genkernel.conf
wget ${CONFIG_SERVER_URI}/gentoo/kernel_config -O /mnt/gentoo/etc/kernels/kernel_config
wget ${CONFIG_SERVER_URI}/gentoo/default_grub -O /mnt/gentoo/etc/default/grub

mkdir -p /mnt/gentoo/usr/lib/systemd/system
wget ${CONFIG_SERVER_URI}/gentoo/hv_fcopy_daemon.service -O /mnt/gentoo/usr/lib/systemd/system/hv_fcopy_daemon.service
wget ${CONFIG_SERVER_URI}/gentoo/hv_vss_daemon.service -O /mnt/gentoo/usr/lib/systemd/system/hv_vss_daemon.service
wget ${CONFIG_SERVER_URI}/gentoo/hv_kvp_daemon.service -O /mnt/gentoo/usr/lib/systemd/system/hv_kvp_daemon.service

# enter the chroot and run the in-chroot script
echo "Entering chroot"

mount -t proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

cp /etc/resolv.conf /mnt/gentoo/etc/resolv.conf

wget ${CONFIG_SERVER_URI}/scripts/provision_gentoo_chroot.sh -O /mnt/gentoo/root/provision_gentoo_chroot.sh
chmod +x /mnt/gentoo/root/provision_gentoo_chroot.sh

chroot /mnt/gentoo /root/provision_gentoo_chroot.sh

# and get ready to reboot
echo "Chroot finished, ready to restart"

umount -l /mnt/gentoo/{proc,sys,dev,boot,}

# hail mary!
reboot
