#!/bin/bash -eux

# Randomize the root password and then lock the root account.
LOCKPWD=`dd if=/dev/urandom count=50 | md5sum | awk -F' ' '{print $1}'`
printf "$LOCKPWD\n$LOCKPWD\n" | passwd root
passwd --lock root
