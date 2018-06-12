#!/bin/bash -eux

# Disable IPv6 for the current boot.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure IPv6 stays disabled.
printf "\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^generic-debian9-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "debian9.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 debian9.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi

# This will ensure the network device is named eth0.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.ifnames=0"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Clear out the existing automatic ifup rules.
sed -i -e '/^auto/d' /etc/network/interfaces
sed -i -e '/^iface/d' /etc/network/interfaces

# Ensure the loopback, and default network interface are automatically enabled and then dhcp'ed.
printf "auto lo\n" >> /etc/network/interfaces;
printf "iface lo inet loopback\n" >> /etc/network/interfaces;
printf "auto eth0\n" >> /etc/network/interfaces;
printf "iface eth0 inet dhcp\n" >> /etc/network/interfaces;

# Adding a delay so dhclient will work properly.
printf "pre-up sleep 2\n" >> /etc/network/interfaces;

# Ensure the networking interfaces get configured on boot.
systemctl enable networking.service

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "nameserver 8.8.8.8\nnameserver 4.2.2.2\n" > /etc/resolv.conf
