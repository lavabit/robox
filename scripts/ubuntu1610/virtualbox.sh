#!/bin/bash

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get --assume-yes install virtualbox-guest-additions-iso

# Read in the version number.
export VBOXVERSION=`cat /root/VBoxVersion.txt`

# export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
# apt-get --assume-yes install dkms build-essential module-assistant linux-headers-$(uname -r)
#
# mkdir -p /mnt/virtualbox
# mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox
#
# /mnt/virtualbox/VBoxLinuxAdditions.run --nox11
# ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions
#
# umount /mnt/virtualbox
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso

# Boosts the available entropy which allows magma to start faster.
#apt-get --assume-yes install haveged

# Autostart the haveged daemon.
#systemctl enable haveged.service || echo Failure.
