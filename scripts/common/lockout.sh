#!/bin/bash -eux

# Randomize the root password and then lock the root account.
LOCKPWD=`dd if=/dev/urandom count=50 | md5sum | awk -F' ' '{print $1}'`
printf "$LOCKPWD\n$LOCKPWD\n" | passwd root


# Handle builds using the busybox version of df/dd/rm which use different command line arguments.
if [[ "$PACKER_BUILD_NAME" =~ ^magma-alpine-vmware$|^magma-alpine-libvirt$|^magma-alpine-virtualbox$ ]]; then
  passwd -l root
else
  passwd --lock root
fi
