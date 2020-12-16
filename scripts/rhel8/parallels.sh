#!/bin/bash -ux

if [ ! -d /media/BaseOS/ ] || [ ! -d /media/AppStream/ ]; then
  mount /dev/cdrom /media || (printf "\nFailed mount RHEL cdrom.\n"; exit 1)
fi

# Needed to check whether we're running atop Parallels.
dnf --assumeyes install dmidecode

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
