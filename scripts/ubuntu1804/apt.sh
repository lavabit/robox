#!/bin/bash

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
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
# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer
systemctl stop snapd.service snapd.socket snapd.refresh.timer

# Update the package database.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" update; error

# Ensure the linux-tools and linux-cloud-tools get updated with the kernel.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" install linux-tools-generic linux-cloud-tools-generic

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
