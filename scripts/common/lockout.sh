#!/bin/bash -eux

# Randomize the root password and then lock the root account.
if [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(freebsd11|openbsd6)-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 | md5 | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root

elif [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(alpine3[5-8])-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 | md5sum | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root
  passwd -l root

else

  LOCKPWD=`dd if=/dev/urandom count=128 | md5sum | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root
  passwd --lock root

fi
