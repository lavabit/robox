#!/bin/bash -eux

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
