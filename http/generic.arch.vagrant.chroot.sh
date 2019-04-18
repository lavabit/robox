#!/bin/bash -eux

ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime

echo 'arch.localdomain' > /etc/hostname

sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

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

systemctl enable sshd
systemctl enable dhcpcd.service

# Ensure the network is always eth0.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.ifnames=0 biosdevname=0 elevator=noop vga=792"/g' /etc/default/grub
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=5/' /etc/default/grub

grub-install "$device"
grub-mkconfig -o /boot/grub/grub.cfg

VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" || $VIRT == "Microsoft Hyper-V" ]]; then

# Hyper-V builds don't reboot properly without the no_timer_check kernel parameter.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 no_timer_check"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

pacman -S --noconfirm git base-devel bind-tools

su -l vagrant -c /bin/bash <<-EOF
cd /home/vagrant/

# The PKGBUILD file seems to use an out-of-date kernel version, so it might be
# necessary to replace it with a version that uses the currently running kernel.
# Note the PKGBUILD files simply download the kernel sources using a v4.x directory,
# which will probably need to be updated when the major version changes.

KERN=\`uname -r | awk -F'-' '{print \$1}' | sed -e 's/\.0$//g'\`
MAJOR=\`uname -r | awk -F'.' '{print \$1}'\`

# hypervvsh
git clone https://aur.archlinux.org/hypervvssd.git hypervvssd && cd hypervvssd
sed --in-place "s/^pkgver=.*/pkgver=\$KERN/g" PKGBUILD
sed --in-place "s/pkgver = .*/pkgver = \$KERN/g" .SRCINFO
sed --in-place "s/https:\/\/www.kernel.org\/pub\/linux\/kernel\/v\$MAJOR.x\/linux-.*.tar.gz/https:\/\/www.kernel.org\/pub\/linux\/kernel\/v\$MAJOR.x\/linux-\$KERN.tar.gz/g" .SRCINFO
makepkg --cleanbuild --noconfirm --syncdeps --install
cd /home/vagrant/ && rm -rf hypervvssd

# hypervkvpd
git clone https://aur.archlinux.org/hypervkvpd.git hypervkvpd && cd hypervkvpd
sed --in-place "s/^pkgver=.*/pkgver=\$KERN/g" PKGBUILD
sed --in-place "s/pkgver = .*/pkgver = \$KERN/g" .SRCINFO
sed --in-place "s/https:\/\/www.kernel.org\/pub\/linux\/kernel\/v\$MAJOR.x\/linux-.*.tar.gz/https:\/\/www.kernel.org\/pub\/linux\/kernel\/v\$MAJOR.x\/linux-\$KERN.tar.gz/g" .SRCINFO
makepkg --cleanbuild --noconfirm --syncdeps --install
cd /home/vagrant/ && rm -rf hypervkvpd

# hypervfcopyd
git clone https://aur.archlinux.org/hypervfcopyd.git hypervfcopyd && cd hypervfcopyd
sed --in-place "s/^pkgver=.*/pkgver=\$KERN/g" PKGBUILD
sed --in-place "s/pkgver = .*/pkgver = \$KERN/g" .SRCINFO
sed --in-place "s/https:\/\/www.kernel.org\/pub\/linux\/kernel\/v\$MAJOR.x\/linux-.*.tar.gz/https:\/\/www.kernel.org\/pub\/linux\/kernel\/v\$MAJOR.x\/linux-\$KERN.tar.gz/g" .SRCINFO
makepkg --cleanbuild --noconfirm --syncdeps --install
cd /home/vagrant/ && rm -rf hypervfcopyd

EOF

systemctl enable hypervkvpd.service
systemctl enable hypervvssd.service
systemctl enable hypervfcopyd.service

fi
