#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-freebsd11-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i "" -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-freebsd11-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i "" -e "s/hostname=\".*\"/hostname=\"freebsd11.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    freebsd11 freebsd11.localdomain\n" >> /etc/hosts
  hostname freebsd11.localdomain
else
  sed -i "" -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  hostname bazinga.localdomain
fi
