#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-openbsd ]]; then
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-openbsd ]]; then
	hostname openbsd.localdomain
else
  hostname bazinga.localdomain
fi
