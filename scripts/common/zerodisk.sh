#!/bin/bash -ux

# Handle builds using the busybox version of df/dd/rm which use different command line arguments.
if [[ "$PACKER_BUILD_NAME" =~ ^magma-alpine3[5-6]-vmware$|^magma-alpine3[5-6]-libvirt$|^magma-alpine3[5-6]-virtualbox$|^generic-alpine3[5-6]-vmware$|^generic-alpine3[5-6]-libvirt$|^generic-alpine3[5-6]-virtualbox$ ]]; then

  # We fill until full so don't abort on error.
  # set -ux

  # Whiteout root
  dd if=/dev/zero of=/zerofill bs=1M
  sync -f /zerofill
  rm -f /zerofill

  # Whiteout /boot
  dd if=/dev/zero of=/boot/zerofill bs=1M
  sync -f /boot/zerofill
  rm -f /boot/zerofill

  echo "All done."
  exit 0

fi

# Whiteout root
count=$(df --sync -kP / | tail -n1  | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/zerofill bs=1M count=$count || echo "dd exit code $? is suppressed"; sync
rm --force /zerofill; sync

# Whiteout /boot
count=$(df --sync -kP /boot | tail -n1 | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/boot/zerofill bs=1M count=$count || echo "dd exit code $? is suppressed"; sync
rm --force /boot/zerofill; sync

# Whiteout the swap partition (if it exists)
swapuuid="`/sbin/blkid -o value -l -s UUID -t TYPE=swap`";
if [ "x${swapuuid}" != "x" ]; then
    swappart="`readlink -f /dev/disk/by-uuid/$swapuuid`";
    /sbin/swapoff "$swappart";
    dd if=/dev/zero of="$swappart" bs=1M || echo "dd exit code $? is suppressed"; sync
    /sbin/mkswap -U "$swapuuid" "$swappart"; sync
fi

# Sync to ensure that the delete completes before we move to the shutdown phase.
sync
sync
sync
