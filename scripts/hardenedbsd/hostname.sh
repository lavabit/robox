#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-hardenedbsd-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf-e
  sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    magma magma.localdomain\n" >> /etc/hosts
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-hardenedbsd-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"hardenedbsd.localdomain\"/g" /etc/defaults/rc.conf-e
  sed -i -e "s/hostname=\".*\"/hostname=\"hardenedbsd.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    hardenedbsd hardenedbsd.localdomain\n" >> /etc/hosts
  hostname hardenedbsd.localdomain
else
  sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf-e
  sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
  printf "\n127.0.0.1    bazinga bazinga.localdomain\n" >> /etc/hosts
  hostname bazinga.localdomain
fi
