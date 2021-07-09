#!/bin/bash

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

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

retry apt-get --assume-yes install virtualbox-guest-utils; error

# Read in the version number.
export VBOXVERSION=`cat /root/VBoxVersion.txt`

# export DEBIAN_FRONTEND=noninteractive
# export DEBCONF_NONINTERACTIVE_SEEN=true
# apt-get --assume-yes install dkms build-essential module-assistant linux-headers-$(uname -r)
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
# # Test if the vboxsf module is present
# [ -s "/lib/modules/$(uname -r)/misc/vboxsf.ko" ]; error
#
# umount /mnt/virtualbox
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso

# Boosts the available entropy which allows magma to start faster.
#apt-get --assume-yes install haveged

# Autostart the haveged daemon.
#systemctl enable haveged.service || echo Failure.
