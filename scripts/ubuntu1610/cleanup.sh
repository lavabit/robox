#!/bin/bash

error() {
  if [ $? -ne 0 ]; then
    printf "\n\napt failed...\n\n";
    exit 1
  fi
}

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Reset the apt sources.
sed -i -e "s/https:\/\/mirrors.lavabit.com/http:\/\/old-releases.ubuntu.com/g" /etc/apt/sources.list

# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer
systemctl stop snapd.service snapd.socket snapd.refresh.timer

# Cleanup unused packages.
apt-get --assume-yes autoremove; error
apt-get --assume-yes autoclean; error

# Clear the random seed.
rm -f /var/lib/systemd/random-seed
