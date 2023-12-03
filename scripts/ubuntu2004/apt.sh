#!/bin/bash

# If the TERM environment variable is set to dumb, tput will generate spurrious error messages.
[ "$TERM" == "dumb" ] && export TERM="vt100"

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
                printf "\n\napt failed...\n\n";
                exit 1
        fi
}

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Temporarily disable IPv6, update the nameservers so packages download
# properly. A more permanent soulution is applied by the network
# configuration script.
sysctl net.ipv6.conf.all.disable_ipv6=1
printf "nameserver 4.2.2.1\nnameserver 4.2.2.2\nnameserver 208.67.220.220\n" > /etc/resolv.conf

# Disable upgrades to new releases.
sed -i -e 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades;

# If the apt configuration directory exists, we add our own config options.
if [ -d /etc/apt/apt.conf.d/ ]; then

# Disable periodic activities of apt.
printf "APT::Periodic::Enable \"0\";\n" >> /etc/apt/apt.conf.d/10periodic

# We disable APT retries, to avoid inconsistent error handling, as it only retries some errors. Instead we let the retry function detect, and retry a given command regardless of the error.
printf "APT::Acquire::Retries \"0\";\n" >> /etc/apt/apt.conf.d/20retries

fi

# Stop the active services/timers.
systemctl --quiet list-unit-files apt-daily.timer &>/dev/null && systemctl --quiet is-active apt-daily.timer && systemctl stop apt-daily.timer
systemctl --quiet list-unit-files apt-daily-upgrade.timer &>/dev/null && systemctl --quiet is-active apt-daily-upgrade.timer && systemctl stop apt-daily-upgrade.timer
systemctl --quiet list-unit-files update-notifier-download.timer &>/dev/null && systemctl --quiet is-active update-notifier-download.timer && systemctl stop update-notifier-download.timer

systemctl --quiet list-unit-files apt-news.service &>/dev/null && systemctl --quiet is-active apt-news.service && systemctl stop apt-news.service
systemctl --quiet list-unit-files apt-daily.service &>/dev/null && systemctl --quiet is-active apt-daily.service && systemctl stop apt-daily.service
systemctl --quiet list-unit-files apt-daily-upgrade.service &>/dev/null && systemctl --quiet is-active apt-daily-upgrade.service && systemctl stop apt-daily-upgrade.service

systemctl --quiet list-unit-files snapd.socket &>/dev/null && systemctl --quiet is-active snapd.socket && systemctl stop snapd.socket
systemctl --quiet list-unit-files snapd.service &>/dev/null && systemctl --quiet is-active snapd.service && systemctl stop snapd.service

systemctl --quiet list-unit-files packagekit.service &>/dev/null && systemctl --quiet is-active packagekit.service && systemctl stop packagekit.service
systemctl --quiet list-unit-files packagekit-offline-update.service &>/dev/null && systemctl --quiet is-active packagekit-offline-update.service && systemctl stop packagekit.service

systemctl --quiet list-unit-files unattended-upgrades.service &>/dev/null && systemctl --quiet is-active unattended-upgrades.service && systemctl stop unattended-upgrades.service
systemctl --quiet list-unit-files update-notifier-download.service &>/dev/null && systemctl --quiet is-active update-notifier-download.service && systemctl stop update-notifier-download.service

# Disable them so they don't restart.
systemctl --quiet list-unit-files apt-daily.timer &>/dev/null && systemctl --quiet is-enabled apt-daily.timer && systemctl disable apt-daily.timer
systemctl --quiet list-unit-files apt-daily-upgrade.timer &>/dev/null && systemctl --quiet is-enabled apt-daily-upgrade.timer && systemctl disable apt-daily-upgrade.timer
systemctl --quiet list-unit-files update-notifier-download.timer &>/dev/null && systemctl --quiet is-enabled update-notifier-download.timer && systemctl disable update-notifier-download.timer

systemctl --quiet list-unit-files apt-news.service &>/dev/null && systemctl --quiet is-enabled apt-news.service && systemctl mask apt-news.service
systemctl --quiet list-unit-files apt-daily.service &>/dev/null && systemctl --quiet is-enabled apt-daily.service && systemctl mask apt-daily.service
systemctl --quiet list-unit-files apt-daily-upgrade.service &>/dev/null && systemctl --quiet is-enabled apt-daily-upgrade.service && systemctl mask apt-daily-upgrade.service

# Package install/update triggers rely on the PackageKit.service to make system changes, and these operations fail
# if the PackageKit.service is masked. So we only disable it.
systemctl --quiet list-unit-files packagekit.service &>/dev/null && systemctl --quiet is-enabled packagekit.service && systemctl disable packagekit.service
systemctl --quiet list-unit-files packagekit-offline-update.service &>/dev/null && systemctl --quiet is-enabled packagekit-offline-update.service && systemctl mask packagekit-offline-update.service

systemctl --quiet list-unit-files snapd.socket &>/dev/null && systemctl --quiet is-enabled snapd.socket && systemctl disable snapd.socket
systemctl --quiet list-unit-files snapd.service &>/dev/null && systemctl --quiet is-enabled snapd.service && systemctl mask snapd.service

systemctl --quiet list-unit-files unattended-upgrades.service &>/dev/null && systemctl --quiet is-enabled unattended-upgrades.service && systemctl mask unattended-upgrades.service
systemctl --quiet list-unit-files update-notifier-download.service &>/dev/null && systemctl --quiet is-enabled update-notifier-download.service && systemctl mask update-notifier-download.service

# An unattended upgrade service doesn't fit the use use case for 
# vagrant boxes, so removal is an option, but since Ubuntu installs 
# it by default, and we want to keep the environment close to the default,
# we'll just leave disabled for now.
# apt-get -qq -y purge unattended-upgrades 
# cat <<-EOF | sudo debconf-set-selections
# unattended-upgrades unattended-upgrades/enable_auto_updates boolean false
# EOF

# Update the package database.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" update; error

# Ensure the linux-tools and linux-cloud-tools get updated with the kernel.
# retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" install linux-tools-generic linux-cloud-tools-generic

# Upgrade the installed packages.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" upgrade; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" dist-upgrade; error

# Needed to retrieve source code, and other misc system tools.
retry apt-get --assume-yes install vim vim-nox gawk git git-man liberror-perl wget curl rsync gnupg mlocate sysstat lsof pciutils usbutils lsb-release psmisc; error

# Enable the sysstat collection service.
sed -i -e "s|.*ENABLED=\".*\"|ENABLED=\"true\"|g" /etc/default/sysstat

# Start the services we just added so the system will track its own performance.
systemctl enable sysstat.service && systemctl start sysstat.service

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Populate the mlocate database during boot.
printf "@reboot root command bash -c '/etc/cron.daily/mlocate'\n" > /etc/cron.d/mlocate
