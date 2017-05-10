#!/bin/bash

# This script grabs several files off the web, but doesn't verify the signature
# for any of them. The best I could do, with little effort, was have them use https.


# Partition the disk.

# sgdisk \
#   -n 1:0:+2M   -t 1:ef00 -c 1:"gptbios" \
#   -n 2:0:+256M -t 2:8300 -c 2:"boot" \
#   -n 3:0:+2G   -t 3:8200 -c 3:"swap" \
#   -n 4:0:0     -t 4:8300 -c 4:"root" \
#   -p /dev/sda
# sync

printf "unit mib\nmkpart primary 1 3\nname 1 grub\nset 1 bios_grub on\nmkpart primary 3 131\nname 2 boot\nset 2 boot on\nmkpart primary 131 643\nname 3 swap\nmkpart primary 643 -1\nname 4 root\nprint\nquit\n" | parted /dev/sda

sync

mkfs.ext2 /dev/sda2
mkswap /dev/sda3
mkfs.ext4 /dev/sda4

# Mount the target partitions.
swapon /dev/sda3

mount /dev/sda4 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount /dev/sda2 /mnt/gentoo/boot

# Grab the current stage 3 tarball.
cd /mnt/gentoo

# current-stage3-amd64-nomultilib
# tarball=$(wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-nomultilib/ -O - | grep -o -e "stage3-amd64-nomultilib-\w*.tar.bz2" | uniq)
# wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-nomultilib/$tarball || exit 1

# current-stage3-amd64-systemd
tarball=$(wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-systemd/ -O - | grep -o -e "stage3-amd64-systemd-\w*.tar.bz2" | uniq)
wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-systemd/$tarball || exit 1

tar xjpf $tarball
rm -f $tarball
echo "Gentoo image applied."

# Setup the file system mounts.
cd /
mount -t proc proc /mnt/gentoo/proc
mount --rbind /dev /mnt/gentoo/dev
mount --rbind /sys /mnt/gentoo/sys

# Setup the domain service resolver.
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Configure the timezone. We use pacific time because it's the most likely to be correct.
chroot /mnt/gentoo /bin/bash <<EOF
ln -snf /usr/share/zoneinfo/US/Pacific /etc/localtime
echo US/Pacific > /etc/timezone
EOF

# Create the fstab file.
cat > /mnt/gentoo/etc/fstab <<EOF
/dev/sda2   /boot        ext2    defaults,noatime     0 2
/dev/sda3   none         swap    sw                   0 0
/dev/sda4   /            ext4    noatime,discard      0 1
EOF

cat > /mnt/gentoo/etc/portage/make.conf <<EOF
CFLAGS="-march=native -O2 -pipe"
CXXFLAGS="${CFLAGS}"
MAKEOPTS="-j2"
EOF

# Setup portage.
chroot /mnt/gentoo /bin/bash <<EOF
mkdir /usr/portage
emerge-webrsync
eselect profile set default/linux/amd64/13.0/systemd
emerge --update --deep --newuse @world
EOF


# chroot /mnt/gentoo /bin/bash <<EOF
# USE="-systemd" emerge --oneshot --quiet-build sys-apps/dbus
# emerge -C udev
# emerge --quiet-build sys-apps/systemd
# ln -sf /proc/self/mounts /etc/mtab
# EOF




# See if we can install a kernel without providing a config file.
# cp $SCRIPTS/scripts/kernel.config /mnt/gentoo/tmp/

#
# chroot /mnt/gentoo /bin/bash <<EOF
# emerge sys-kernel/gentoo-sources
# emerge sys-kernel/genkernel
# cd /usr/src/linux
# mv /tmp/kernel.config .config
# genkernel --install --symlink --no-zfs --no-btrfs --oldconfig all
# emerge -c sys-kernel/genkernel
# EOF





# Setup grub.
# chroot /mnt/gentoo /bin/bash <<EOF
# emerge "sys-boot/os-prober"
# emerge ">=sys-boot/grub-2.0"
#
# echo 'GRUB_DEFAULT=0' >> /etc/default/grub
# echo 'GRUB_TIMEOUT=10' >> /etc/default/grub
# echo 'GRUB_TERMINAL=console' >> /etc/default/grub
# echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
# echo 'GRUB_TERMINAL_OUTPUT="console"'
# echo 'GRUB_DISABLE_SUBMENU=true' >> /etc/default/grub
# echo 'GRUB_CMDLINE_LINUX="init=/usr/lib/systemd/systemd console=tty1"' >> /etc/default/grub
#
# # echo "set timeout=10" >> /etc/grub.d/40_custom
#
# # chmod -x /etc/grub.d/[0-9]*
# # chmod +x /etc/grub.d/{00_header,10_linux,30_os-prober,40_custom}
#
# # mount -o rw,remount /boot
#
# grub-install --no-floppy /dev/sda
# grub-mkconfig -o /boot/grub/grub.cfg
# EOF





#
# chroot /mnt/gentoo /bin/bash <<EOF
# source /etc/profile
# if [ -d /sys/firmware/efi ]; then
#   mkdir -p /etc/portage/package.use
#   echo 'sys-boot/grub grub_platforms_efi-32 grub_platforms_efi-64' > /etc/portage/package.use/grub
# fi
# emerge --noreplace -v sys-boot/grub
#
# if ! grep -q '^# gentoo-build systemd' /etc/default/grub; then
#   echo '# gentoo-build systemd' >> /etc/default/grub
#   echo 'GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX} init=/usr/lib/systemd/systemd"' >> /etc/default/grub
# fi
#
# if grep -q ' /boot ' /proc/mounts; then
#   if ! grep ' /boot ' /proc/mounts | grep -q rw; then
#     mount -o rw,remount /boot
#   fi
# fi
#
# if ! grep ' / ' /proc/mounts | grep -q rw; then
#   mount -o rw,remount /
# fi
#
# grub-install --no-floppy /dev/${GB_ROOTDEVICE}
# grub-mkconfig -o /boot/grub/grub.cfg
# EOF

# Make the memory and cpus hotplugable.
chroot /mnt/gentoo /bin/bash <<EOF
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

sed -i 's|.*UseDNS.*|UseDNS no|g' /etc/ssh/sshd_config
sed -i 's|.*UsePAM,*|UsePAM yes|g' /etc/ssh/sshd_config
sed -i 's|.*PermitRootLogin.*|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed -i 's|.*PubkeyAuthentication|PubkeyAuthentication|g' /etc/ssh/sshd_config
sed -i 's|.*GSSAPIAuthentication.*|GSSAPIAuthentication yes|g' /etc/ssh/sshd_config
sed -i 's|.*GSSAPICleanupCredentials.*|GSSAPICleanupCredentials no|g' /etc/ssh/sshd_config
sed -i 's|.*PasswordAuthentication.*|PasswordAuthentication yes|g' /etc/ssh/sshd_config

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

echo 'sshd:ALL' > /etc/hosts.allow
echo 'ALL:ALL' > /etc/hosts.deny
EOF
#
# iface="${GB_IFACE}"
# if [ -z "${iface}" ]; then
#   iface="$(ip -o r get 8.8.8.8|sed -e's/ \+/ /g'|sed -re 's/^.*dev ([^ ]+) .*$/\1/')"
#   echo "NOTICE: assuming default iface is ${iface}"
# fi
#
# cat >  /mnt/gentoo/etc/systemd/network/default.network <<EOF
# [Match]
# Name=${iface}
# [Network]
# DHCP=both
# [DHCP]
# UseDomains=yes
# EOF
#
# chroot /mnt/gentoo /bin/bash <<EOF
# source /etc/profile
# ln -sfv /usr/lib64/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/systemd-networkd.service
# ln -sfv /usr/lib64/systemd/system/systemd-resolved.service /etc/systemd/system/multi-user.target.wants/systemd-resolved.service
# EOF
#
chroot /mnt/gentoo /bin/bash <<EOF
echo "magma.builder" > /etc/hostname
EOF

# Configure the system password which will be used after the reboot.
chroot /mnt/gentoo /bin/bash <<EOF
passwd<<PEOF
vagrant
vagrant
PEOF
EOF

# Configure the vagrant user account.
chroot /mnt/gentoo /bin/bash <<EOF
useradd vagrant
passwd vagrant<<PEOF
vagrant
vagrant
PEOF

mkdir -p ~vagrant/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key' > ~vagrant/.ssh/authorized_keys

chmod 600 ~vagrant/.ssh/authorized_keys
chmod 700 ~vagrant/.ssh

chown vagrant:vagrant ~vagrant/.ssh/authorized_keys
chown vagrant:vagrant ~vagrant/.ssh
EOF

nohup /bin/bash -c 'shutdown -r 0 &'
exit 0
