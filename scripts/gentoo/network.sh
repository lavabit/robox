#!/bin/bash -eux

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "nameserver 4.2.2.1\nnameserver 4.2.2.2\nnameserver 208.67.220.220\n"> /etc/resolv.conf

# Disable IPv6 for the current boot.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure IPv6 stays disabled.
printf "\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.d/local.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^generic-gentoo-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "gentoo.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 gentoo.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi
