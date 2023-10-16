#!/bin/bash -eux

echo 'arch.localdomain' > /etc/hostname

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

sed -i -e 's/^#default_options=""/default_options="-S autodetect"/g' /etc/mkinitcpio.d/linux.preset
mkinitcpio -p linux

echo -e 'locked\nlocked' | passwd

mkdir -p /etc/systemd/network
ln -sf /dev/null /etc/systemd/network/99-default.link
cat <<-EOF > /etc/systemd/network/eth0.network
[Match]
Name=eth0

[Network]
DHCP=ipv4
EOF

sed -i -e "s/#DNS=.*/DNS=4.2.2.1 4.2.2.2 208.67.220.220/g" /etc/systemd/resolved.conf
sed -i -e "s/#FallbackDNS=.*/FallbackDNS=4.2.2.1 4.2.2.2 208.67.220.220/g" /etc/systemd/resolved.conf
sed -i -e "s/#Domains=.*/Domains=/g" /etc/systemd/resolved.conf
sed -i -e "s/#Cache=.*/Cache=yes/g" /etc/systemd/resolved.conf
sed -i -e "s/#DNSStubListener=.*/DNSStubListener=yes/g" /etc/systemd/resolved.conf

# DNSSEC is broken for now.
# sed -i -e "s/#DNSSEC=.*/DNSSEC=yes/g" /etc/systemd/resolved.conf

cat <<-EOF > /etc/resolv.conf
nameserver 4.2.2.1
nameserver 4.2.2.2
nameserver 208.67.220.220
EOF

#systemctl enable dhcpcd
systemctl enable systemd-networkd
systemctl enable systemd-resolved
rm --force /run/systemd/generator.early/sshd.service && systemctl enable sshd

# Ensure the network is always eth0.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.ifnames=0 biosdevname=0 elevator=noop vga=792"/g' /etc/default/grub
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=5/' /etc/default/grub

# Install grub.
grub-install "$device" || exit 1
grub-mkconfig -o /boot/grub/grub.cfg || exit 1
