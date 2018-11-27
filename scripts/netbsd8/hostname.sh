#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-netbsd8-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  echo "magma.localdomain" > /etc/myname
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-netbsd8-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "\n127.0.0.1    netbsd8 netbsd8.localdomain\n" >> /etc/hosts
  echo "netbsd8.localdomain" > /etc/myname
  hostname netbsd8.localdomain
else
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  echo "bazinga.localdomain" > /etc/myname
  hostname bazinga.localdomain
fi
