#!/bin/bash


error() {
  if [ $? -ne 0 ]; then
    printf "\n\nThe VirtualBox install failed...\n\n"
    exit 1
  fi
}

zypper --non-interactive install --force-resolution dmidecode; error

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

zypper --non-interactive install --force-resolution virtualbox-guest-tools virtualbox-guest-kmp-default; error

rm -rf /root/VBoxVersion.txt; error
rm -rf /root/VBoxGuestAdditions.iso; error
