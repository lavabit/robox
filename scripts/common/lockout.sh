#!/bin/bash -eux

# Randomize the root password and then lock the root account.
if [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(freebsd1[1-2]|hardenedbsd1[1-2]|openbsd6)-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 msgfmt=quiet | md5 | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root

elif  [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(dragonflybsd5)-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 msgfmt=quiet | md5 | awk -F' ' '{print $1}'`
  echo "$LOCKPWD" | pw mod user root -h 0

elif  [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(netbsd8)-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 msgfmt=quiet | md5 | awk -F' ' '{print $1}'`
  /usr/sbin/user mod -p "`pwhash $LOCKPWD`" root

elif [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(alpine3[5-9]|alpine310)-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 status=none | md5sum | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root
  passwd -l root

else

  LOCKPWD=`dd if=/dev/urandom count=128 status=none | md5sum | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root
  passwd --lock root

fi
