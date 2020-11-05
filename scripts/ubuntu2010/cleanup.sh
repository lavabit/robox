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

# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer
systemctl stop snapd.service snapd.socket snapd.refresh.timer

# KVP daemon fails to start on first boot of disco VM.
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1820063
# https://askubuntu.com/a/1204263
systemctl disable hv-kvp-daemon.service

# Cleanup unused packages.
apt-get --assume-yes autoremove; error
apt-get --assume-yes autoclean; error

# Clear the random seed.
rm -f /var/lib/systemd/random-seed
