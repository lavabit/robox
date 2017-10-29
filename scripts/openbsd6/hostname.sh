#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-openbsd ]]; then
  hostname magma.localdomain
	sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-openbsd ]]; then
	hostname openbsd.localdomain
	sed -i -e "s/hostname=\".*\"/hostname=\"openbsd.localdomain\"/g" /etc/defaults/rc.conf
else
  hostname bazinga.localdomain
	sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
fi
