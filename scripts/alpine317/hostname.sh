#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-alpine317-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  echo "magma.localdomain" > /etc/hostname
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-alpine317-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    alpine317 alpine317.localdomain\n" >> /etc/hosts
  echo "alpine317.localdomain" > /etc/hostname
  hostname alpine317.localdomain
else
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  echo "bazinga.localdomain" > /etc/hostname
  hostname bazinga.localdomain
fi
