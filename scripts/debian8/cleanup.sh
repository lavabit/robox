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

# Keep the daily apt/aptitude cron jobs from deadlocking our cleanup operations.
systemctl --quiet is-active cron.service && systemctl stop cron.service

# Cleanup unused packages.
apt-get -y purge installation-report &>/dev/null || true
apt-get --assume-yes autoremove; error
apt-get --assume-yes autoclean; error
apt-get --assume-yes purge; error

# Restore the system default apt retry value.
[ -f /etc/apt/apt.conf.d/20retries ] && rm --force /etc/apt/apt.conf.d/20retries

# Remove the random seed so a unique value is used the first time the box is booted.
systemctl --quiet is-active systemd-random-seed.service && systemctl stop systemd-random-seed.service
[ -f /var/lib/systemd/random-seed ] && rm --force /var/lib/systemd/random-seed

# Reset the system date. Because the date is current wrong, we need to ignore certificate errors.
date -s "`curl --insecure -I 'https://google.com/' 2>/dev/null | grep -i '^date:' | sed 's/^[Dd]ate: //g'`"

# But assuming the above request worked, and the system time has been corrected, we can try again securely to confirm.
date -s "`curl -I 'https://google.com/' 2>/dev/null | grep -i '^date:' | sed 's/^[Dd]ate: //g'`" || \
{  printf "\n\nSystem date/time update failed...\n\n" ; exit exit 1 ; }


