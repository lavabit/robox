#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nvbox install failed...\n\n";
                exit 1
        fi
}

# Bail if we are not running inside VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

export DEBIAN_FRONTEND=noninteractive
apt-get --assume-yes install virtualbox-guest-additions-iso; error

# # Read in the version number.
# export VBOXVERSION=`cat /root/VBoxVersion.txt`
#
# export DEBIAN_FRONTEND=noninteractive
# apt-get --assume-yes install build-essential libc6 libcurl3 libdevmapper1.02.1 libgcc1 libpng12-0 libpython2.7 libssl1.0.0 libstdc++6 libvpx3 libxml2 zlib1g psmisc adduser kmod dkms module-init-tools gcc make binutils dpkg-dev linux-image linux-headers linux-headers-generic linux-headers-amd64 linux-headers-`uname -r`; error
#
# mkdir -p /mnt/virtualbox; error
# mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox; error
#
# /mnt/virtualbox/VBoxLinuxAdditions.run --nox11; error
# ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions; error
#
# umount /mnt/virtualbox; error
rm -rf /root/VBoxVersion.txt; error
rm -rf /root/VBoxGuestAdditions.iso; error

# Boosts the available entropy which allows magma to start faster.
apt-get --assume-yes install haveged; error

# Autostart the haveged daemon.
systemctl enable haveged.service
