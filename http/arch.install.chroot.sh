#!/bin/bash

set -e
set -x

ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime

echo 'archlinux' > /etc/hostname

sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

mkinitcpio -p linux

echo -e 'vagrant\nvagrant' | passwd
useradd -m -U vagrant
echo -e 'vagrant\nvagrant' | passwd vagrant
cat <<EOF > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty
vagrant ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/vagrant
sed -i -e "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config

mkdir -p /etc/systemd/network
ln -sf /dev/null /etc/systemd/network/99-default.link

systemctl enable sshd
systemctl enable dhcpcd@eth0

grub-install "$device"
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
