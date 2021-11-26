#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-dragonflybsd6-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-dragonflybsd6-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"dragonflybsd6.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    dragonflybsd6 dragonflybsd6.localdomain\n" >> /etc/hosts
  hostname dragonflybsd6.localdomain
else
  sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  hostname bazinga.localdomain
fi
