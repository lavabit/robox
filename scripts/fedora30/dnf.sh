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
                printf "\n\ndnf failed...\n\n";
                exit 1
        fi
}

# Tell dnf to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
printf "\nretries=128\ndeltarpm=false\nmetadata_expire=20\ntimeout=300\n" >> /etc/dnf/dnf.conf

# Disable the subscription manager plugin.
if [ -f /etc/yum/pluginconf.d/subscription-manager.conf ]; then
  sed --in-place "s/^enabled=.*/enabled=0/g" /etc/yum/pluginconf.d/subscription-manager.conf
fi

# And disable the subscription maangber via the alternate dnf config file.
if [ -f /etc/dnf/plugins/subscription-manager.conf ]; then
  sed --in-place "s/^enabled=.*/enabled=0/g" /etc/dnf/plugins/subscription-manager.conf
fi

# Disable IPv6 or dnf will resolve mirror names to IPv6 address and then fail to connect with them.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Update the base install first.
retry dnf upgrade --assumeyes; error

# Needed to retrieve source code, and other misc system tools.
retry dnf install --assumeyes vim git wget curl rsync gnupg sysstat lsof pciutils usbutils psmisc; error

# Packages needed beyond a minimal install to build and run magma.
retry dnf install --assumeyes valgrind valgrind-devel texinfo autoconf automake libtool ncurses-devel gcc-c++ libstdc++-devel gcc cpp glibc-devel glibc-headers kernel-headers mpfr ppl perl perl-Module-Pluggable perl-Pod-Escapes perl-Pod-Simple perl-libs perl-version patch sysstat perl-Time-HiRes make cmake libarchive deltarpm net-tools; error

# Grab the required packages from the EPEL repo.
retry dnf install --assumeyes libbsd libbsd-devel inotify-tools; error

# Boosts the available entropy which allows magma to start faster.
retry dnf install --assumeyes haveged; error

# The daemon services magma relies upon.
retry dnf install --assumeyes libevent memcached; error

# Packages used to retrieve the magma code, but aren't required for building/running the daemon.
retry dnf install --assumeyes wget git rsync perl-Git perl-Error; error

# These packages are required for the stacie.py script, which requires the python cryptography package (installed via pip).
retry dnf install --assumeyes python-crypto python-cryptography

# Packages used during the provisioning process and then removed during the cleanup stage.
retry dnf install --assumeyes sudo dmidecode; error

# Run update a second time, just in case it failed the first time. Mirror timeoutes and cosmic rays
# often interupt the the provisioning process.
retry dnf upgrade --assumeyes; error

# Reboot onto the new kernel (if applicable).
( shutdown --reboot --no-wall +1 ) &
exit 0

