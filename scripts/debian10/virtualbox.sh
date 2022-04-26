#!/bin/bash

retry() {
  local COUNT=1
  local DELAY=0
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

    if [ -f /var/log/VBoxGuestAdditions.log ]; then
      printf "\n\n/var/log/VBoxGuestAdditions.log\n\n"
      cat /var/log/VBoxGuestAdditions.log
    else
      printf "\n\nThe /var/log/VBoxGuestAdditions.log is missing...\n\n"
    fi

    if [ -f /var/log/vboxadd-install.log ]; then
      printf "\n\n/var/log/vboxadd-install.log\n\n"
      cat /var/log/vboxadd-install.log
    else
      printf "\n\nThe /var/log/vboxadd-install.log is missing...\n\n"
    fi

    if [ -f /var/log/vboxadd-setup.log ]; then
      printf "\n\n/var/log/vboxadd-setup.log\n\n"
      cat /var/log/vboxadd-setup.log
    else
      printf "\n\nThe /var/log/vboxadd-setup.log is missing...\n\n"
    fi

    exit 1
  fi
}

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# Read in the version number.
VBOXVERSION=`cat /root/VBoxVersion.txt`


# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

retry apt-get --assume-yes install dkms build-essential module-assistant linux-headers-$(uname -r); error

# The group vboxsf is needed for shared folder access.
getent group vboxsf >/dev/null || groupadd --system vboxsf; error
getent passwd vboxadd >/dev/null || useradd --system --gid bin --home-dir /var/run/vboxadd --shell /sbin/nologin vboxadd; error

mkdir -p /mnt/virtualbox; error
mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox; error

# Exit code 2 is not really an error here, it just means that the installer wasn't able to (re)load the module.
# Since Linux has in-tree vboxguest and vboxvideo starting with kernel 4.16 we weren't able to reload it after installation.
sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11 || [ $? -eq 2 ]; error
ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions; error

# Test if the vboxsf module is present
[ -s "/lib/modules/$(uname -r)/misc/vboxsf.ko" ]; error

umount /mnt/virtualbox; error
rm -rf /root/VBoxVersion.txt; error
rm -rf /root/VBoxGuestAdditions.iso; error

# Boosts the available entropy which allows magma to start faster.
retry apt-get --assume-yes install haveged; error

# Autostart the haveged daemon.
systemctl enable haveged.service
