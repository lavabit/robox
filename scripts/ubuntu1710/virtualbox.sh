#!/bin/bash

error() {
  if [ $? -ne 0 ]; then
    printf "\n\nThe VirtualBox install failed...\n\n"
    exit 1
  fi
}

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get --assume-yes install virtualbox-guest-additions-iso; error

# Read in the version number.
export VBOXVERSION=`cat /root/VBoxVersion.txt`

# export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
# apt-get --assume-yes install dkms build-essential module-assistant linux-headers-$(uname -r); error
#
# # The group vboxsf is needed for shared folder access.
# getent group vboxsf >/dev/null || groupadd --system vboxsf; error
# getent passwd vboxadd >/dev/null || useradd --system --gid bin --home-dir /var/run/vboxadd --shell /sbin/nologin vboxadd; error
#
# mkdir -p /mnt/virtualbox; error
# mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox; error
#
# # For some reason the vboxsf module fails the first time, but installs
# # successfully if we run the installer a second time.
# sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11 || sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11; error
# ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions; error
#
# umount /mnt/virtualbox; error
rm -rf /root/VBoxVersion.txt; error
rm -rf /root/VBoxGuestAdditions.iso; error

# Boosts the available entropy which allows magma to start faster.
apt-get --assume-yes install haveged; error

# Autostart the haveged daemon.
systemctl enable haveged.service
