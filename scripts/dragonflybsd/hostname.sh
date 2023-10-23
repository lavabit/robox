#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-dragonflybsd-(vmware|hyperv|libvirt|parallels|virtualbox)-(x64|x32|a64|a32|p64|p32|m64|m32)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-dragonflybsd-(vmware|hyperv|libvirt|parallels|virtualbox)-(x64|x32|a64|a32|p64|p32|m64|m32)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"dragonflybsd.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    dragonflybsd dragonflybsd.localdomain\n" >> /etc/hosts
  hostname dragonflybsd.localdomain
else
  sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  hostname bazinga.localdomain
fi
