#!/bin/bash -eux

if [[ "$PACKER_BUILD_NAME" =~ ^magma-freebsd11 ]]; then
  hostname magma.localdomain
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-freebsd11 ]]; then
	hostname freebsd.localdomain
else
  hostname bazinga.localdomain
fi
