#!/bin/bash -ux

if [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(freebsd1[1-4]|hardenedbsd|hardenedbsd1[1-3]|openbsd[6-7]|alpine3[5-9]|alpine31[0-9])-(vmware|hyperv|libvirt|parallels|virtualbox)-(x64|x32|a64|a32|p64|p32|m64|m32)$ ]]; then 

  # We fill until full so don't abort on error.
  # set -ux

  # Whiteout root
  ( dd if=/dev/zero of=/zerofill_1 bs=1M || echo "dd /zerofill_1 exited ( $? ) " ) &
  ( dd if=/dev/zero of=/zerofill_2 bs=1M || echo "dd /zerofill_2 exited ( $? ) " ) &
  ( dd if=/dev/zero of=/zerofill_3 bs=1M || echo "dd /zerofill_3 exited ( $? ) " ) &
  ( dd if=/dev/zero of=/zerofill_4 bs=1M || echo "dd /zerofill_4 exited ( $? ) " ) &

  # ####
  # ( dd if=/dev/zero of=/zerofill_5 bs=1M || echo "dd /zerofill_5 exited ( $? ) " ) &
  # ( dd if=/dev/zero of=/zerofill_6 bs=1M || echo "dd /zerofill_6 exited ( $? ) " ) &

  wait 

  sync -f /zerofill_1
  sync -f /zerofill_2
  sync -f /zerofill_3
  sync -f /zerofill_4

  # ####
  # sync -f /zerofill_5
  # sync -f /zerofill_6

  rm -f /zerofill_1 /zerofill_2 /zerofill_3 /zerofill_4

  # ####
  # rm -f /zerofill_5 /zerofill_6

  # Whiteout /boot. We assume if the amount of free space on /boot and / 
  # are the same, it's the same device and we don't need to run the zerofill again.
  if [ -d "/boot" ] && [ "$(df -m / | tail -1 | awk -F' ' '{print $4}')" != \
    "$(df -m /boot | tail -1 | awk -F' ' '{print $4}')" ]; then

    ( dd if=/dev/zero of=/boot/zerofill_1 bs=1M || echo "dd /boot/zerofill_1 exited ( $? ) " ) &
    ( dd if=/dev/zero of=/boot/zerofill_2 bs=1M || echo "dd /boot/zerofill_2 exited ( $? ) " ) &
    ( dd if=/dev/zero of=/boot/zerofill_3 bs=1M || echo "dd /boot/zerofill_3 exited ( $? ) " ) &
    ( dd if=/dev/zero of=/boot/zerofill_4 bs=1M || echo "dd /boot/zerofill_4 exited ( $? ) " ) &

    wait 
  
    sync -f /boot/zerofill_1
    sync -f /boot/zerofill_2
    sync -f /boot/zerofill_3
    sync -f /boot/zerofill_4
    rm -f /boot/zerofill_1 /boot/zerofill_2 /boot/zerofill_3 /boot/zerofill_4

  fi

elif [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(netbsd[8-9])-(vmware|hyperv|libvirt|parallels|virtualbox)-(x64|x32|a64|a32|p64|p32|m64|m32)$ ]]; then

  # Whiteout root.
  dd if=/dev/zero of=/zerofill bs=1m msgfmt=human
  sync -f /zerofill
  rm -f /zerofill

elif [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(dragonflybsd[5-6]?)-(vmware|hyperv|libvirt|parallels|virtualbox)-(x64|x32|a64|a32|p64|p32|m64|m32)$ ]]; then

  AVAIL=`df -m / | tail -1 | awk -F' ' '{print $4}'`
  let FILL=${AVAIL}-256

  dd if=/dev/zero of=/zerofill bs=1M count=$FILL
  sync -f /zerofill
  rm -f /zerofill

else

  # Whiteout the root partition.
  rootcount=$(df --sync -mP / | tail -n1  | awk -F ' ' '{print $4}')
  rootcount=$(($rootcount/4))
  ( dd if=/dev/zero of=/zerofill_1 bs=1M count=$rootcount || echo "dd exit code $? suppressed" ) &
  ( dd if=/dev/zero of=/zerofill_2 bs=1M count=$rootcount || echo "dd exit code $? suppressed" ) &
  ( dd if=/dev/zero of=/zerofill_3 bs=1M count=$rootcount || echo "dd exit code $? suppressed" ) &
  ( dd if=/dev/zero of=/zerofill_4 bs=1M count=$rootcount || echo "dd exit code $? suppressed" ) &
  wait ; sync || echo "sync exit code $? suppressed"
  rm --force /zerofill_1 /zerofill_2 /zerofill_3 /zerofill_4

  # Whiteout boot if the block count is different then root, otherwise if the
  # block counts are identical, we assume both folders are on the same partition.
  rootcount=$(df --sync -mP / | tail -n1  | awk -F ' ' '{print $4}')
  rootcount=$(($rootcount-1))
  bootcount=$(df --sync -mP /boot | tail -n1 | awk -F ' ' '{print $4}')
  bootcount=$(($bootcount-1))
  if [ $rootcount != $bootcount ]; then
    dd if=/dev/zero of=/boot/zerofill bs=1M count=$bootcount || echo "dd exit code $? suppressed"
    sync || echo "sync exit code $? suppressed"
    rm --force /boot/zerofill
  fi

  # If blkid is installed we use it to locate the swap partition.
  if [ -f '/sbin/blkid' ]; then
    swapuuid="`/sbin/blkid -o value -l -s UUID -t TYPE=swap`"
  else
    swapuuid=""
  fi

  # Whiteout the swap partition.
  if [ "x${swapuuid}" != "x" ]; then
    swappart="`readlink -f /dev/disk/by-uuid/$swapuuid`"
    /sbin/swapoff "$swappart"
    dd if=/dev/zero of="$swappart" bs=1M || echo "dd exit code $? suppressed"
    /sbin/mkswap -U "$swapuuid" "$swappart"
  fi

fi

# Sync to ensure that the delete completes before we move to the shutdown phase.
sync
sync
sync

echo "All done."
exit 0
