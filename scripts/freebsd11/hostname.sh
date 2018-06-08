#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-freebsd11-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-freebsd11-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"freebsd.localdomain\"/g" /etc/defaults/rc.conf
  hostname freebsd.localdomain
else
  sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
  hostname bazinga.localdomain
fi
