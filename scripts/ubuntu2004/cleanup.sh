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

# We should be able to run the following, but removing popularity-contest also removes the ubuntu-standard
# package. The latter package contents are trivial, as it only contains a copyright notice, but its
# presence signifies that the system is a "standard" Ubuntu installation, so we leave it be.
# apt-get -y purge popularity-contest installation-report &>/dev/null || true

# Instead of using the above, we use this version, which only removes the installation report package.
apt-get -y purge installation-report &>/dev/null || true

# Cleanup unused packages.
apt-get --assume-yes autoremove; error
apt-get --assume-yes autoclean; error
apt-get --assume-yes purge; error

# Restore the system default apt retry value.
[ -f /etc/apt/apt.conf.d/20retries ] && rm --force /etc/apt/apt.conf.d/20retries

# Remove the random seed so a unique value is used the first time the box is booted.
systemctl --quiet is-active systemd-random-seed.service && systemctl stop systemd-random-seed.service
[ -f /var/lib/systemd/random-seed ] && rm --force /var/lib/systemd/random-seed

# *Unmask anything we might have masked in the apt module.
systemctl --quiet list-unit-files apt-news.service &>/dev/null && [ "$(systemctl is-enabled apt-news.service)" == "masked" ] && systemctl unmask apt-news.service
systemctl --quiet list-unit-files apt-daily.service &>/dev/null && [ "$(systemctl is-enabled apt-daily.service)" == "masked" ] && systemctl unmask apt-daily.service
# systemctl --quiet list-unit-files apt-daily-upgrade.service &>/dev/null && [ "$(systemctl is-enabled apt-daily-upgrade.service)" == "masked" ] && systemctl unmask apt-daily-upgrade.service

systemctl --quiet list-unit-files packagekit.service &>/dev/null && [ "$(systemctl is-enabled packagekit.service)" == "disabled" ] && systemctl enable packagekit.service
systemctl --quiet list-unit-files packagekit-offline-update.service &>/dev/null && [ "$(systemctl is-enabled packagekit-offline-update.service)" == "masked" ] && systemctl unmask packagekit-offline-update.service

systemctl --quiet list-unit-files snapd.service &>/dev/null && [ "$(systemctl is-enabled snapd.service)" == "masked" ] && systemctl unmask snapd.service
systemctl --quiet list-unit-files snapd.socket &>/dev/null && [ "$(systemctl is-enabled snapd.socket)" == "disabled" ] && systemctl enable snapd.socket
