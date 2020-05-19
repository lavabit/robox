#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
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
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# Ensure the pkg utilities are in the path.
export PATH="/usr/sbin/:/usr/pkg/bin/:$PATH"

# Dictate the package repository.
export PKG_PATH="http://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/8.2/All"

# Ensure dmideocode is available.
retry pkg_add dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `/usr/pkg/sbin/dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso
