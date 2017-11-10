#!/bin/bash -eux

ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime

echo 'magma.builder' > /etc/hostname

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
systemctl enable dhcpcd@eth0

# Ensure the network is always eth0.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.ifnames=0"/g' /etc/default/grub
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=5/' /etc/default/grub

grub-install "$device"
grub-mkconfig -o /boot/grub/grub.cfg

VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" ]]; then

    pacman -S --noconfirm git base-devel

    su -l vagrant -c /bin/bash <<-EOF
    cd $HOME

    # hypervvsh
    git clone https://aur.archlinux.org/hypervvssd.git hypervvssd
    cd hypervvssd
    makepkg --cleanbuild --noconfirm --syncdeps --install
    cd $HOME && rm -rf hypervvssd

    # hypervkvpd
    git clone https://aur.archlinux.org/hypervkvpd.git hypervkvpd
    cd hypervkvpd
    makepkg --cleanbuild --noconfirm --syncdeps --install
    cd $HOME && rm -rf hypervkvpd

    # hypervfcopyd
    git clone https://aur.archlinux.org/hypervfcopyd.git hypervfcopyd
    cd hypervfcopyd
    makepkg --cleanbuild --noconfirm --syncdeps --install
    cd $HOME && rm -rf hypervfcopyd
EOF
    systemctl enable hypervkvpd.service
    systemctl enable hypervvssd.service
fi
