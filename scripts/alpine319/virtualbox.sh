#!/bin/bash -x

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
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
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Ensure dmidecode is available.
retry apk add dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from the Linux Guest Additions ISO.
printf "Installing the Virtual Box Tools.\n"

# Add the edge package repo.
# printf "@edge-main https://mirrors.edge.kernel.org/alpine/edge/main\n" >> /etc/apk/repositories
# printf "@edge-testing https://mirrors.edge.kernel.org/alpine/edge/testing\n" >> /etc/apk/repositories
# printf "@edge-community https://mirrors.edge.kernel.org/alpine/edge/community\n" >> /etc/apk/repositories

# Update the package list.
# retry apk update --no-cache

# Install the VirtualBox kernel modules for guest services.
# retry apk add virtualbox-guest-modules-virt@edge-community virtualbox-guest-additions@edge-community
retry apk add virtualbox-guest-additions

# Autoload the virtualbox kernel modules.
rc-update add virtualbox-guest-additions default && rc-service virtualbox-guest-additions start

# Cleanup.
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso

# Boosts the available entropy which allows magma to start faster.
retry apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start
