#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-fedora28-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  echo "magma.localdomain" > /etc/hostname
  hostnamectl set-hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-fedora28-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    fedora28 fedora28.localdomain\n" >> /etc/hosts
  echo "fedora28.localdomain" > /etc/hostname
  hostnamectl set-hostname fedora28.localdomain
else
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  echo "bazinga.localdomain" > /etc/hostname
  hostnamectl set-hostname bazinga.localdomain
fi
