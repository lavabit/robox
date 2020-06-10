#!/bin/bash -ex

# If the TERM environment variable is missing, then tput may produce spurrious error messages.
if [[ ! -n "$TERM" ]] || [[ "$TERM" -eq "dumb" ]]; then
  export TERM="vt100"
fi

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

# Needed to check whether we're running atop Parallels.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

retry apt-get --assume-yes install dmidecode

# Bail if we are not running atop Parallels.
if [[ `dmidecode -s system-product-name` != "Parallels Virtual Platform" ]]; then
    exit 0
fi

# Flex is required, but doesn't get automatically installed by the Parallels installer.
retry apt-get --assume-yes install flex bison

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
