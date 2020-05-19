#!/bin/bash -ux

if [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(freebsd1[1-2]|hardenedbsd1[1-2]|netbsd[8-9]|openbsd6|alpine3[5-9]|alpine31[0-1])-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  # We fill until full so don't abort on error.
  # set -ux

  # Whiteout root
  dd if=/dev/zero of=/zerofill bs=1K
  sync -f /zerofill
  rm -f /zerofill

  # Whiteout /boot
  if [ -d "/boot" ]; then
    dd if=/dev/zero of=/boot/zerofill bs=1K
    sync -f /boot/zerofill
    rm -f /boot/zerofill
  fi


elif [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(dragonflybsd5)-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

  AVAIL=`df -m / | tail -1 | awk -F' ' '{print $4}'`
  let FILL=${AVAIL}-256

  dd if=/dev/zero of=/zerofill bs=1M count=$FILL
  sync -f /zerofill
  rm -f /zerofill

else

  # Whiteout root
  rootcount=$(df --sync -kP / | tail -n1  | awk -F ' ' '{print $4}')
  rootcount=$(($rootcount-1))
  dd if=/dev/zero of=/zerofill bs=1K count=$rootcount || echo "dd exit code $? suppressed"
  rm --force /zerofill

  # Whiteout boot if the block count is different then root, otherwise if the
  # block counts are identical, we assume both folders are on the same parition
  bootcount=$(df --sync -kP /boot | tail -n1 | awk -F ' ' '{print $4}')
  bootcount=$(($bootcount-1))
  if [ $rootcount != $bootcount ]; then
    dd if=/dev/zero of=/boot/zerofill bs=1K count=$bootcount || echo "dd exit code $? suppressed"
    rm --force /boot/zerofill
  fi

  # If blkid is installed it to locate the swap partition
  if [ -f '/sbin/blkid' ]; then
    swapuuid="`/sbin/blkid -o value -l -s UUID -t TYPE=swap`"
  else
    swapuuid=""
  fi

  # Whiteout the swap partition
  if [ "x${swapuuid}" != "x" ]; then
    swappart="`readlink -f /dev/disk/by-uuid/$swapuuid`"
    /sbin/swapoff "$swappart"
    dd if=/dev/zero of="$swappart" bs=1K || echo "dd exit code $? suppressed"
    /sbin/mkswap -U "$swapuuid" "$swappart"
  fi

fi

# Sync to ensure that the delete completes before we move to the shutdown phase.
sync
sync
sync

echo "All done."
exit 0
