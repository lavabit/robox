#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-openbsd6-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  echo "magma.localdomain" > /etc/myname
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-openbsd6-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    openbsd6 openbsd6.localdomain\n" >> /etc/hosts
  echo "openbsd6.localdomain" > /etc/myname
  hostname openbsd6.localdomain
else
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  echo "bazinga.localdomain" > /etc/myname
  hostname bazinga.localdomain
fi
