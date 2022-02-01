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

# Keep the daily apt updater from deadlocking our cleanup commands.
systemctl --quiet is-active snapd.service && systemctl stop snapd.service snapd.socket
systemctl --quiet is-active packagekit.service && systemctl stop packagekit.service
systemctl --quiet is-active apt-daily.timer && systemctl stop apt-daily.timer
systemctl --quiet is-active apt-daily.service && systemctl stop apt-daily.service
systemctl --quiet is-active apt-daily-upgrade.timer && systemctl stop apt-daily-upgrade.timer
systemctl --quiet is-active apt-daily-upgrade.service && systemctl stop apt-daily-upgrade.service
systemctl --quiet is-active unattended-upgrades.service && systemctl stop unattended-upgrades.service
systemctl --quiet is-active update-notifier-donwload.service && systemctl stop update-notifier-donwload.service

# Remove cloud init packages.
dpkg -l eatmydata &>/dev/null && apt-get --assume-yes purge eatmydata
dpkg -l libeatmydata1 &>/dev/null && apt-get --assume-yes purge libeatmydata1
dpkg -l cloud-init &>/dev/null && apt-get --assume-yes purge cloud-init

# We can probably also remove unattended-upgrades ... but we'll save that for later.
# dpkg -l unattended-upgrades &>/dev/null && apt-get --assume-yes purge unattended-upgrades

# Cleanup unused packages.
apt-get --assume-yes autoremove; error
apt-get --assume-yes autoclean; error

# Restore the system default apt retry value.
[ -f /etc/apt/apt.conf.d/20retries ] && rm --force /etc/apt/apt.conf.d/20retries

# Remove leftover config files/directories.
[ -d /etc/cloud/ ] && rm --recursive --force /etc/cloud/

# Remove the workaround IP address for old-releases if its present.
sed -i '/old-releases.ubuntu.com/d' /etc/hosts

# Remove log files.
[ -d /var/log/dist-upgrade/ ] && rm --recursive --force /var/log/dist-upgrade/ 
[ -d /var/log/installer/ ] && rm --recursive --force /var/log/installer/ 

[ -f /var/log/apt/eipp.log.xz ] && rm --force /var/log/apt/eipp.log.xz
[ -f /var/log/cloud-init-output.log ] && rm --force /var/log/cloud-init-output.log
[ -f /var/log/cloud-init.log ] && rm --force /var/log/cloud-init.log
[ -f /var/log/bootstrap.log ] && rm --force /var/log/bootstrap.log
[ -f /var/log/dmesg.1.gz ] && rm --force /var/log/dmesg.1.gz
[ -f /var/log/dmesg.0 ] && rm --force /var/log/dmesg.0
[ -f /var/log/dmesg ] && rm --force /var/log/dmesg

[ -f /var/log/apt/history.log ] && truncate --size=0 truncate --size=0 /var/log/apt/history.log 
[ -f /var/log/apt/term.log ] && truncate --size=0 truncate --size=0 /var/log/apt/term.log
[ -f /var/log/ubuntu-advantage-timer.log ] && truncate --size=0 truncate --size=0 /var/log/ubuntu-advantage-timer.log
[ -f /var/log/ubuntu-advantage.log ] && truncate --size=0 truncate --size=0 /var/log/ubuntu-advantage.log
[ -f /var/log/alternatives.log ] && truncate --size=0 truncate --size=0 /var/log/alternatives.log
[ -f /var/log/dpkg.log ] && truncate --size=0 truncate --size=0 /var/log/dpkg.log
[ -f /var/log/kern.log ] && truncate --size=0 /var/log/kern.log
[ -f /var/log/syslog ] && truncate --size=0 /var/log/syslog

# Remove the random seed so a unique value is used the first time the box is booted.
systemctl --quiet is-active systemd-random-seed.service && systemctl stop systemd-random-seed.service
[ -f /var/lib/systemd/random-seed ] && rm --force /var/lib/systemd/random-seed

