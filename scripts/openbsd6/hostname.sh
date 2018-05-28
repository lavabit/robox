#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-openbsd-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  echo "magma.localdomain" > /etc/myname
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-openbsd-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  echo "openbsd.localdomain" > /etc/myname
  hostname openbsd.localdomain
else
  echo "bazinga.localdomain" > /etc/myname
  hostname bazinga.localdomain
fi
