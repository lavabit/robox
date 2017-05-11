#!/bin/bash -eux

# Disable IPv6 for the current boot.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure IPv6 stays disabled.
printf "\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "\nnameserver 4.2.2.1\nnameserver 4.2.2.2\n" > /etc/resolv.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^lineage-vmware$|^lineage-libvirt$|^lineage-virtualbox$ ]]; then
  printf "lineage.builder\n" > /etc/hostname
  printf "\n127.0.0.1 lineage.builder\n\n" >> /etc/hosts
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-ubuntu1604-vmware$|^generic-ubuntu1604-libvirt$|^generic-ubuntu1604-virtualbox$ ]]; then
  printf "ubuntu1604.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 ubuntu1604.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi

# Adding a delay so dhclient will work properly.
printf "pre-up sleep 2\n" >> /etc/network/interfaces;

# Ensure the networking interfaces get configured on boot.
systemctl enable networking.service
