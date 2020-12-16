#!/bin/bash -ux

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -f /media/media.repo ]; then
  mount /dev/cdrom /media
fi

# Needed to check whether we're running atop Parallels.
yum --assumeyes install dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
    exit 0
fi

# Read in the version number.
PARALLELSVERSION=`cat /root/parallels-tools-version.txt`

echo "Installing the Parallels tools, version $PARALLELSVERSION."

mkdir -p /mnt/parallels/
mount -o loop /root/parallels-tools-linux.iso /mnt/parallels/

/mnt/parallels/install --install-unattended-with-deps --verbose --progress \
  || (status="$?" ; echo "Parallels tools installation failed. Error: $status" ; cat /var/log/parallels-tools-install.log ; exit $status)

umount /mnt/parallels/
rmdir /mnt/parallels/

# Cleanup the guest additions.
rm --force /root/parallels-tools-linux.iso
rm --force /root/parallels-tools-version.txt
