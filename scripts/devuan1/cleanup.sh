#!/bin/bash

error() {
  if [ $? -ne 0 ]; then
    printf "\n\napt failed...\n\n";
    exit 1
  fi
}

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Cleanup unused packages.
apt-get --assume-yes autoremove; error
apt-get --assume-yes autoclean; error
apt-get --assume-yes purge; error

# Restore the system default apt retry value.
[ -f /etc/apt/apt.conf.d/20retries ] && rm --force /etc/apt/apt.conf.d/20retries

# Remove the random seed so a unique value is used the first time the box is booted.
[ -f /etc/init.d/urandom ] && /etc/init.d/urandom stop
[ -f /var/lib/urandom/random-seed ] && rm --force /var/lib/urandom/random-seed
