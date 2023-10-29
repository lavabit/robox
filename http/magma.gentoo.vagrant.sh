#!/bin/bash -xe

echo 'Syncing the System Clock'
ntpdate 0.us.pool.ntp.org 1.us.pool.ntp.org 2.us.pool.ntp.org

echo 'Preparing Filesystem to Install Gentoo'

echo 'Partitioning Filesystems'
declare -i current=1
parted -a opt -s /dev/sda -- "mklabel gpt"
parted -a opt -s /dev/sda -- "mkpart EFI fat16       $(( current ))  $(( current += 128   ))m"
parted -a opt -s /dev/sda -- "mkpart BOOT ext4       $(( current ))  $(( current += 512   ))m"
parted -a opt -s /dev/sda -- "mkpart SWAP linux-swap $(( current ))m $(( current += 4096  ))m"
parted -a opt -s /dev/sda -- "mkpart ROOT ext4       $(( current ))m -1"
parted -a opt -s /dev/sda -- "set 1 bios_grub on"
parted -a opt -s /dev/sda -- "set 2 boot on"

echo 'Formatting Filesystems'
mkfs.fat -F 32 -n efi-boot /dev/sda1
mkfs -t ext4 /dev/sda2
mkfs -t ext4 /dev/sda4

echo 'Mounting Filesystems in /mnt/gentoo'
mkswap /dev/sda3
swapon /dev/sda3
mount /dev/sda4 /mnt/gentoo/
mkdir -p /mnt/gentoo/{boot,var,usr,tmp,home}
mount /dev/sda2 /mnt/gentoo/boot
mkdir -p /mnt/gentoo/boot/{grub,efi}
mount /dev/sda1 /mnt/gentoo/boot/efi

# Import current keys per https://www.gentoo.org/downloads/signatures/
wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import

# Remove expired keys
expired_keys="$(gpg --list-keys --fixed-list-mode --with-colons | grep "^pub:e:" | cut -f5 -d":")"
for key in ${expired_keys} ; do gpg --no-greeting --batch --yes --delete-key "${key}" ; done

cd /mnt/gentoo

# Download the current-stage3-amd64-nomultilib and the portage tarballs, unpack them, and then delete the archive files.
echo 'Downloading Image Overlay'
# host="https://gentoo.osuosl.org"
host="https://mirrors.edge.kernel.org/gentoo"
tarball=$(wget -q $host/releases/amd64/autobuilds/current-stage3-amd64-nomultilib-openrc/ -O - | grep -E -v "tar\.xz\.asc|tar\.xz\.CONTENTS\.gz|tar\.xz\.DIGESTS|tar\.xz\.sha256" | grep -E -o -e "stage3-amd64-nomultilib-openrc-[0-9]{8}T[0-9]{6}Z.tar.xz" | sort -V | uniq | tail -1)
wget --tries=5 --progress=dot:binary $host/releases/amd64/autobuilds/current-stage3-amd64-nomultilib-openrc/$tarball || exit 1
wget --tries=5 -q $host/releases/amd64/autobuilds/current-stage3-amd64-nomultilib-openrc/$tarball.asc || exit 1
wget --tries=5 -q $host/releases/amd64/autobuilds/current-stage3-amd64-nomultilib-openrc/$tarball.DIGESTS || exit 1

echo 'Downloading Portage'
wget --tries=5 --progress=dot:binary $host/snapshots/portage-latest.tar.bz2 || exit 1
wget --tries=5 -q $host/snapshots/portage-latest.tar.bz2.gpgsig || exit 1

echo 'Signature Verification'
gpg --verify $tarball.asc $tarball || exit 1
gpg --verify portage-latest.tar.bz2.gpgsig portage-latest.tar.bz2 || exit 1
grep --after-context=1 SHA512 $tarball.DIGESTS | grep -vE "CONTENTS|^#|^\-\-$" | sha512sum --check || exit 1

echo 'Extracting Gentoo Tarball'
tar xJpf $tarball && rm -f $tarball $tarball.asc $tarball.DIGESTS

echo 'Extracting Portage Tarball'
tar xjpf portage-latest.tar.bz2 -C '/mnt/gentoo/usr' && rm -f portage-latest.tar.bz2 portage-latest.tar.bz2.gpgsig

# Copy the resolv config and rebind the dynamic system directories.
mount -t proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
cp /etc/resolv.conf /mnt/gentoo/etc

# Execute the chroot script.
chroot /mnt/gentoo /bin/bash < /root/magma.gentoo.vagrant.chroot.sh

# If the chroot starts failing, use this command instead to see where it is failing.
# (chroot /mnt/gentoo /bin/bash -ex < /root/magma.gentoo.vagrant.chroot.sh) || exit 1

# And then reboot.
echo "Chroot finished, ready to restart."
reboot
