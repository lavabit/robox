#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-freebsd ]]; then
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-freebsd ]]; then
	hostname freebsd.localdomain
else
  hostname bazinga.localdomain
fi
