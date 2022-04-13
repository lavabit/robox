#!/bin/bash

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
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

# The Ubuntu cloud tools package automatically installs kernel drivers and background
# services for several virtualization platforms. Crude runtime dependency checks should
# block unnecessary drivers from loading, and unnecessary services from starting, but this 
# strategy still generates spurious log messages, along with an (albeit slight) performance
# penalty. So reduce noise, and avoid any performance penalties we disable and mask 
# guest drivers/services which don't match the target virtualization platform.
systemctl --quiet is-enabled hv-fcopy-daemon.service &> /dev/null && \
  ( systemctl disable hv-fcopy-daemon.service ; systemctl mask hv-fcopy-daemon.service ) || \
  echo "hv-fcopy-daemon.service already disabled" &> /dev/null
systemctl --quiet is-enabled hv-kvp-daemon.servicee &> /dev/null && \
  ( systemctl disable hv-kvp-daemon.service ; systemctl mask hv-kvp-daemon.service ) || \
  echo "hv-kvp-daemon.service already disabled" &> /dev/null
systemctl --quiet is-enabled hv-vss-daemon.servicee &> /dev/null && \
  ( systemctl disable hv-vss-daemon.service ; systemctl mask hv-vss-daemon.service ) || \
  echo "hv-vss-daemon.servicee already disabled" &> /dev/null
systemctl --quiet is-enabled open-vm-tools.servicee &> /dev/null && \
  ( systemctl disable open-vm-tools.service ; systemctl mask open-vm-tools.service ) || \
  echo "open-vm-tools.servicee already disabled" &> /dev/null

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

retry apt-get --assume-yes install virtualbox-guest-utils ; error

# Read in the version number.
export VBOXVERSION=`cat /root/VBoxVersion.txt`
#
# export DEBIAN_FRONTEND=noninteractive
# export DEBCONF_NONINTERACTIVE_SEEN=true
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
# # Test if the vboxsf module is present
# [ -s "/lib/modules/$(uname -r)/misc/vboxsf.ko" ]; error
#
# umount /mnt/virtualbox; error
rm -rf /root/VBoxVersion.txt; error
rm -rf /root/VBoxGuestAdditions.iso; error

# Boosts the available entropy which allows magma to start faster.
retry apt-get --assume-yes install haveged; error

# Autostart the haveged daemon.
systemctl enable haveged.service
