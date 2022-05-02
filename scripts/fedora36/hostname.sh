#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-fedora36-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  echo "magma.localdomain" > /etc/hostname
  hostnamectl set-hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-fedora36-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    fedora36 fedora36.localdomain\n" >> /etc/hosts
  echo "fedora36.localdomain" > /etc/hostname
  hostnamectl set-hostname fedora36.localdomain
else
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  echo "bazinga.localdomain" > /etc/hostname
  hostnamectl set-hostname bazinga.localdomain
fi
