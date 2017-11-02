#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-openbsd ]]; then
  echo "magma.localdomain" > /etc/myname
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-openbsd ]]; then
  echo "openbsd.localdomain" > /etc/myname
  hostname openbsd.localdomain
else
  echo "bazinga.localdomain" > /etc/myname
  hostname bazinga.localdomain
fi
