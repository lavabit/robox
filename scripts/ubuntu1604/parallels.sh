#!/bin/bash -ux

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

# Needed to check whether we're running atop Parallels.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

retry apt-get --assume-yes install dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
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
systemctl --quiet is-enabled hv-kvp-daemon.service &> /dev/null && \
  ( systemctl disable hv-kvp-daemon.service ; systemctl mask hv-kvp-daemon.service ) || \
  echo "hv-kvp-daemon.service already disabled" &> /dev/null
systemctl --quiet is-enabled hv-vss-daemon.service &> /dev/null && \
  ( systemctl disable hv-vss-daemon.service ; systemctl mask hv-vss-daemon.service ) || \
  echo "hv-vss-daemon.service already disabled" &> /dev/null
systemctl --quiet is-enabled open-vm-tools.service &> /dev/null && \
  ( systemctl disable open-vm-tools.service ; systemctl mask open-vm-tools.service ) || \
  echo "open-vm-tools.service already disabled" &> /dev/null
systemctl --quiet is-enabled virtualbox-guest-utils.service &> /dev/null && \
  ( systemctl disable virtualbox-guest-utils.service ; systemctl mask virtualbox-guest-utils.service ) || \
  echo "virtualbox-guest-utils.service already disabled" &> /dev/null
  
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
