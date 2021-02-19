#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-fedora31-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  echo "magma.localdomain" > /etc/hostname
  hostnamectl set-hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-fedora31-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    fedora31 fedora31.localdomain\n" >> /etc/hosts
  echo "fedora31.localdomain" > /etc/hostname
  hostnamectl set-hostname fedora31.localdomain
else
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  echo "bazinga.localdomain" > /etc/hostname
  hostnamectl set-hostname bazinga.localdomain
fi
