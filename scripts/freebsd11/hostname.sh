#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-freebsd ]]; then
  hostname magma.localdomain
	sed -i -e "s/hostname=\".*\"/hostname=\"magma.localdomain\"/g" /etc/defaults/rc.conf
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-freebsd ]]; then
	hostname freebsd.localdomain
	sed -i -e "s/hostname=\".*\"/hostname=\"freebsd.localdomain\"/g" /etc/defaults/rc.conf
else
  hostname bazinga.localdomain
	sed -i -e "s/hostname=\".*\"/hostname=\"bazinga.localdomain\"/g" /etc/defaults/rc.conf
fi
