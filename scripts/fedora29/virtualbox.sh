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

    # if [ -f /var/log/VBoxGuestAdditions.log ]; then
    #   printf "\n\n/var/log/VBoxGuestAdditions.log\n\n"
    #   cat /var/log/VBoxGuestAdditions.log
    # else
    #   printf "\n\nThe /var/log/VBoxGuestAdditions.log is missing...\n\n"
    # fi
    #
    # if [ -f /var/log/vboxadd-install.log ]; then
    #   printf "\n\n/var/log/vboxadd-install.log\n\n"
    #   cat /var/log/vboxadd-install.log
    # else
    #   printf "\n\nThe /var/log/vboxadd-install.log is missing...\n\n"
    # fi
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

retry dnf install --assumeyes virtualbox-guest-additions; error

# umount /mnt/virtualbox; error
rm -rf /root/VBoxVersion.txt; error
rm -rf /root/VBoxGuestAdditions.iso; error
