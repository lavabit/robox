#!/bin/bash -eux

# Randomize the root password and then lock the root account.
if [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(freebsd1[1-3]|hardenedbsd1[1-3]|openbsd[6-7])-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 msgfmt=quiet | md5 | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root

elif  [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(dragonflybsd[5-6])-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 status=value | md5 | awk -F' ' '{print $1}'`
  echo "$LOCKPWD" | pw mod user root -h 0
  pwd_mkdb /etc/master.passwd

elif  [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(netbsd[8-9])-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 msgfmt=quiet | md5 | awk -F' ' '{print $1}'`
  /usr/sbin/user mod -p "`pwhash $LOCKPWD`" root

elif [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(alpine3[5-9]|alpine31[0-4])-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  LOCKPWD=`dd if=/dev/urandom count=128 status=none | md5sum | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root
  passwd -l root

else

  LOCKPWD=`dd if=/dev/urandom count=128 status=none | md5sum | awk -F' ' '{print $1}'`
  printf "$LOCKPWD\n$LOCKPWD\n" | passwd root
  passwd --lock root

fi
