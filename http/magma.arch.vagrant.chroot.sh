#!/bin/bash -eux

echo 'magma.localdomain' > /etc/hostname

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

sed -i -e 's/^#default_options=""/default_options="-S autodetect"/g' /etc/mkinitcpio.d/linux.preset
mkinitcpio -p linux

echo -e 'vagrant\nvagrant' | passwd
useradd -m -U vagrant
echo -e 'vagrant\nvagrant' | passwd vagrant
cat <<-EOF > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty
vagrant ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/vagrant
sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

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
sed -i -e "s/#DNSSEC=.*/DNSSEC=yes/g" /etc/systemd/resolved.conf
sed -i -e "s/#Cache=.*/Cache=yes/g" /etc/systemd/resolved.conf
sed -i -e "s/#DNSStubListener=.*/DNSStubListener=yes/g" /etc/systemd/resolved.conf

cat <<-EOF > /etc/resolv.conf
nameserver 4.2.2.1
nameserver 4.2.2.2
nameserver 208.67.220.220
EOF

systemctl enable dhcpcd
systemctl enable systemd-networkd
systemctl enable systemd-resolved
rm --force /run/systemd/generator.early/sshd.service && systemctl enable sshd

# Ensure the network is always eth0.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.ifnames=0 biosdevname=0 elevator=noop vga=792"/g' /etc/default/grub
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=5/' /etc/default/grub

# Install grub.
grub-install "$device"
grub-mkconfig -o /boot/grub/grub.cfg

# Detect Hyper-V and install the kernel modules.
VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" || $VIRT == "Microsoft Hyper-V" ]]; then

# Hyper-V builds don't reboot properly without the no_timer_check kernel parameter.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 no_timer_check"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

pacman -S --noconfirm git base-devel

cd /home/vagrant/

KERN=`uname -r | awk -F'-' '{print $1}' | sed -e 's/\.0$//g'`

# hypervvssd
sudo git clone https://aur.archlinux.org/hypervvssd.git hypervvssd && chown -R vagrant:vagrant hypervvssd && cd hypervvssd
sed --in-place "s/^pkgver=.*/pkgver=$KERN/g" PKGBUILD
su --preserve-environment vagrant --command "makepkg --cleanbuild --noconfirm --syncdeps --install"
cd /home/vagrant/ && rm -rf hypervvssd

# hypervkvpd
sudo git clone https://aur.archlinux.org/hypervkvpd.git hypervkvpd && chown -R vagrant:vagrant hypervkvpd && cd hypervkvpd
sed --in-place "s/^pkgver=.*/pkgver=$KERN/g" PKGBUILD
su --preserve-environment vagrant --command "makepkg --cleanbuild --noconfirm --syncdeps --install"
cd /home/vagrant/ && rm -rf hypervkvpd

# hypervfcopyd
sudo git clone https://aur.archlinux.org/hypervfcopyd.git hypervfcopyd && chown -R vagrant:vagrant hypervfcopyd && cd hypervfcopyd
sed --in-place "s/^pkgver=.*/pkgver=$KERN/g" PKGBUILD
su --preserve-environment vagrant --command "makepkg --cleanbuild --noconfirm --syncdeps --install"
cd /home/vagrant/ && rm -rf hypervfcopyd

systemctl enable hypervkvpd.service
systemctl enable hypervvssd.service
systemctl enable hypervfcopyd.service

fi
