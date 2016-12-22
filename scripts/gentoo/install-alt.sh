#!/bin/bash

# This script grabs several files off the web, but doesn't verigy the signature
# for any of them. The best I could do, with little effort, was have them use https.


# Partition the disk.
sgdisk \
  -n 1:0:+512M -t 1:8300 -c 1:"linux-boot" \
  -n 2:0:+32M  -t 2:ef02 -c 2:"bios-boot"  \
  -n 3:0:+2G   -t 3:8200 -c 3:"swap"       \
  -n 4:0:0     -t 4:8300 -c 4:"linux-root" \
  -p /dev/sda

sync

mkfs.ext2 /dev/sda1
mkfs.ext4 /dev/sda4

mkswap /dev/sda3 && swapon /dev/sda3

# Mount the target partition.
mount /dev/sda4 /mnt/gentoo

# Grab the current stage 3 tarball.
cd /mnt/gentoo
tarball=$(wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-systemd/ -O - | grep -o -e "stage3-amd64-systemd-\w*.tar.bz2" | uniq)
wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-systemd/$tarball || exit 1
tar xjpf $tarball
rm -f $tarball
echo "Gentoo image applied."

# Setup the file system mounts.
cd /
mount /dev/sda1 /mnt/gentoo/boot
mount -t proc proc /mnt/gentoo/proc
mount --rbind /dev /mnt/gentoo/dev
mount --rbind /sys /mnt/gentoo/sys

# Setup the domain service resolver.
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Setup portage.
chroot /mnt/gentoo /bin/bash <<'EOF'
mkdir /usr/portage
emerge-webrsync
EOF

# Configure the timezone. We use pacific time because it's the most likely to be correct.
chroot /mnt/gentoo /bin/bash <<'EOF'
ln -snf /usr/share/zoneinfo/US/Pacific /etc/localtime
echo US/Pacific > /etc/timezone
EOF

# Create the fstab file.
chroot /mnt/gentoo /bin/bash <<'EOF'
cat > /etc/fstab <<'DATA'
# <fs>		<mount>	<type>	<opts>		<dump/pass>
/dev/sda1	/boot	ext2	noauto,noatime	1 2
/dev/sda4	/	ext4	noatime		0 1
/dev/sda3	none	swap	sw		0 0
DATA
EOF

# See if we can install a kernel without providing a config file.
#cp $SCRIPTS/scripts/kernel.config /mnt/gentoo/tmp/
chroot /mnt/gentoo /bin/bash <<'EOF'
emerge sys-kernel/gentoo-sources
emerge sys-kernel/genkernel
cd /usr/src/linux
#mv /tmp/kernel.config .config
genkernel --install --symlink --oldconfig all
emerge -c sys-kernel/genkernel
EOF

# Setup grub.
chroot /mnt/gentoo /bin/bash <<'EOF'
emerge ">=sys-boot/grub-2.0"
echo "set timeout=0" >> /etc/grub.d/40_custom
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Make the memory and cpus hotplugable.
chroot /mnt/gentoo /bin/bash <<'EOF'
cat > /etc/udev/rules.d/80-hotplug-cpu-mem.rules <<'DATA'
# Hotplug physical CPU
SUBSYSTEM=="cpu", ACTION=="add", TEST=="online", ATTR{online}=="0", ATTR{online}="1"

# Hotplug physical memory
SUBSYSTEM=="memory", ACTION=="add", TEST=="state", ATTR{state}=="offline", ATTR{state}="online"
DATA
EOF

# Configure the network to initialize during boot.
chroot /mnt/gentoo /bin/bash <<EOF

ln -sf /dev/null /etc/udev/rules.d/80-net-setup-link.rules
ln -sf /dev/null /etc/udev/rules.d/80-net-name-slot.rules
ln -sf /dev/null /etc/systemd/network/99-default.link

sed -i 's/\#Pub/Pub/g' /etc/ssh/sshd_config
sed -i 's|.*PermitRootLogin.*|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed 's|.*UseDNS.*|UseDNS no|g' -i /etc/ssh/sshd_config
sed -i 's|GSSAPIAuthentication yes|GSSAPIAuthentication no|g'  /etc/ssh/sshd_config
sed -i 's|PasswordAuthentication no|PasswordAuthentication yes|g' /etc/ssh/sshd_config

systemd-firstboot --setup-machine-id
systemctl enable sshd.service
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

cat <<REOF > /etc/systemd/network/dhcp.network
[Match]
Name=e*

[Network]
DHCP=yes

[DHCPv4]
UseHostname=false
REOF
EOF


nohup /bin/bash -c 'shutdown -r now &'
exit 0
