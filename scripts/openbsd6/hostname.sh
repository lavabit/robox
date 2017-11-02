#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-openbsd ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-openbsd ]]; then
  sed -i -e "s/hostname=\".*\"/hostname=\"openbsd.localdomain\"/g" /etc/defaults/rc.conf
  hostname openbsd.localdomain
else
  sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
  hostname bazinga.localdomain
fi
