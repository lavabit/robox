#!/bin/bash -ex

# If the TERM environment variable is set to dumb, tput will generate spurrious error messages. 
[ "$TERM" == "dumb" ] && export TERM="vt100"

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
                printf "\n\nAPT failed... again.\n\n";
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

# Disable upgrades to new releases, and prevent notifications from being added to motd.
sed -i -e 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades 

if [ -f /usr/lib/ubuntu-release-upgrader/release-upgrade-motd ]; then
cat <<-EOF > /usr/lib/ubuntu-release-upgrader/release-upgrade-motd
#!/bin/sh
if [ -d /var/lib/ubuntu-release-upgrader/ ]; then
  date +%s > /var/lib/ubuntu-release-upgrader/release-upgrade-available 
fi
exit 0
EOF
fi

# Remove a confusing, and potentially conflicting sources file left by the install process.
[ -f /etc/apt/sources.list.curtin.old ] && rm --force /etc/apt/sources.list.curtin.old 

# If the APT configuration directory exists, we add our own config options.
if [ -d /etc/apt/apt.conf.d/ ]; then

# Disable APT periodic so it doesn't cause problems.
if [ -f  /etc/apt/apt.conf.d/10periodic ]; then
  sed -i "/^APT::Periodic::Enable/d" /etc/apt/apt.conf.d/10periodic
  sed -i "/^APT::Periodic::AutocleanInterval/d" /etc/apt/apt.conf.d/10periodic
  sed -i "/^APT::Periodic::Unattended-Upgrade/d" /etc/apt/apt.conf.d/10periodic
  sed -i "/^APT::Periodic::Update-Package-Lists/d" /etc/apt/apt.conf.d/10periodic
  sed -i "/^APT::Periodic::Download-Upgradeable-Packages/d" /etc/apt/apt.conf.d/10periodic
fi

cat <<-EOF >> /etc/apt/apt.conf.d/10periodic

APT::Periodic::Enable "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";

EOF

# We disable APT retries, to avoid inconsistent error handling, as it only retries some errors. Instead we let the retry function detect, and retry a given command regardless of the error.
cat <<-EOF >> /etc/apt/apt.conf.d/20retries

APT::Acquire::Retries "0";

EOF

fi

# Keep the daily apt updater from deadlocking our the upgrade/install commands we are about to run.
# systemctl --quiet is-active snapd.service && systemctl stop snapd.service snapd.socket

# Stop the active servicees/timers.
systemctl --quiet is-active apt-daily.timer && systemctl stop apt-daily.timer
systemctl --quiet is-active apt-daily-upgrade.timer && systemctl stop apt-daily-upgrade.timer
systemctl --quiet is-active update-notifier-download.timer && systemctl stop update-notifier-download.timer
systemctl --quiet is-active apt-daily.service && systemctl stop apt-daily.service
systemctl --quiet is-active packagekit.service && systemctl stop packagekit.service
systemctl --quiet is-active apt-daily-upgrade.service && systemctl stop apt-daily-upgrade.service
systemctl --quiet is-active unattended-upgrades.service && systemctl stop unattended-upgrades.service
systemctl --quiet is-active update-notifier-download.service && systemctl stop update-notifier-download.service

# Disable them so they don't restart.
systemctl --quiet is-enabled apt-daily.timer && systemctl disable apt-daily.timer
systemctl --quiet is-enabled apt-daily-upgrade.timer && systemctl disable apt-daily-upgrade.timer
systemctl --quiet is-enabled update-notifier-download.timer && systemctl disable update-notifier-download.timer
systemctl --quiet is-enabled unattended-upgrades.service && systemctl disable unattended-upgrades.service
systemctl --quiet is-enabled apt-daily.service && systemctl mask apt-daily.service
systemctl --quiet is-enabled apt-daily-upgrade.service && systemctl mask apt-daily-upgrade.service
systemctl --quiet is-enabled update-notifier-download.service && systemctl mask update-notifier-download.service

# Truncate the sources list in order to force a status purge.
truncate --size=0 /etc/apt/sources.list

# Run clean/autoclean/purge/update first, this will work around problems with ghost packages, and/or
# conflicting data in the repo index cache. After the cleanup is complete, we can proceed with the 
# update/upgrade/install commands below.
apt-get --assume-yes clean ; error
apt-get --assume-yes autoclean ; error
apt-get --assume-yes purge ; error
apt-get --assume-yes update ; error

# Write out a nice and compact sources list.
cat <<-EOF > /etc/apt/sources.list

deb https://old-releases.ubuntu.com/ubuntu/ groovy main restricted universe multiverse
deb https://old-releases.ubuntu.com/ubuntu/ groovy-updates main restricted universe multiverse
deb https://old-releases.ubuntu.com/ubuntu/ groovy-backports main restricted universe multiverse
deb https://old-releases.ubuntu.com/ubuntu/ groovy-security main restricted universe multiverse

# deb-src https://old-releases.ubuntu.com/ubuntu/ groovy main restricted universe multiverse
# deb-src https://old-releases.ubuntu.com/ubuntu/ groovy-updates main restricted universe multiverse
# deb-src https://old-releases.ubuntu.com/ubuntu/ groovy-backports main restricted universe multiverse
# deb-src https://old-releases.ubuntu.com/ubuntu/ groovy-security main restricted universe multiverse

EOF

# Some of the ubuntu archive servers appear to be missing files/packages..
printf "\n91.189.91.124 old-releases.ubuntu.com\n" >> /etc/hosts

# Update the package database.
retry apt-get --assume-yes --allow-releaseinfo-change -o Dpkg::Options::="--force-confnew" update ; error

# Ensure the linux-tools and linux-cloud-tools get updated with the kernel.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" install linux-cloud-tools-virtual

# Upgrade the installed packages.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" upgrade ; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" dist-upgrade ; error

# Needed to retrieve source code, and other misc system tools.
retry apt-get --assume-yes install vim vim-nox gawk git git-man liberror-perl wget curl rsync gnupg mlocate sudo sysstat lsof pciutils usbutils lsb-release psmisc ; error

# Enable the sysstat collection service.
sed -i -e "s|.*ENABLED=\".*\"|ENABLED=\"true\"|g" /etc/default/sysstat

# Start the services we just added so the system will track its own performance.
systemctl enable sysstat.service && systemctl start sysstat.service

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Populate the mlocate database during boot.
printf "@reboot root command bash -c '/etc/cron.daily/mlocate'\n" > /etc/cron.d/mlocate
