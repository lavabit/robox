#!/bin/bash

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

error() {
        if [ $? -ne 0 ]; then
                printf "\n\napt failed...\n\n";
                exit 1
        fi
}

# To allow for autmated installs, we disable interactive configuration steps.
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

# Enable retries, which should reduce the number box buld failures resulting from a temporal network problems.
printf "APT::Periodic::Enable \"0\";\n" >> /etc/apt/apt.conf.d/20retries

fi
# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer
systemctl stop snapd.service snapd.socket snapd.refresh.timer

# Overwrite the sources.list file.
cat <<-EOF > /etc/apt/sources.list
# deb cdrom:[Ubuntu-Server 17.04 _Zesty Zapus_ - Release amd64 (20170412)]/ zesty main restricted
# deb cdrom:[Ubuntu-Server 17.04 _Zesty Zapus_ - Release amd64 (20170412)]/ zesty main restricted

# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://old-releases.ubuntu.com/ubuntu zesty main restricted
# deb-src http://old-releases.ubuntu.com/ubuntu zesty main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb http://old-releases.ubuntu.com/ubuntu zesty-updates main restricted
# deb-src http://old-releases.ubuntu.com/ubuntu zesty-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb http://old-releases.ubuntu.com/ubuntu zesty universe
# deb-src http://old-releases.ubuntu.com/ubuntu zesty universe
deb http://old-releases.ubuntu.com/ubuntu zesty-updates universe
# deb-src http://old-releases.ubuntu.com/ubuntu zesty-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb http://old-releases.ubuntu.com/ubuntu zesty multiverse
# deb-src http://old-releases.ubuntu.com/ubuntu zesty multiverse
deb http://old-releases.ubuntu.com/ubuntu zesty-updates multiverse
# deb-src http://old-releases.ubuntu.com/ubuntu zesty-updates multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb http://old-releases.ubuntu.com/ubuntu zesty-backports main restricted universe multiverse
# deb-src http://old-releases.ubuntu.com/ubuntu zesty-backports main restricted universe multiverse

## Uncomment the following two lines to add software from Canonical's
## 'partner' repository.
## This software is not part of Ubuntu, but is offered by Canonical and the
## respective vendors as a service to Ubuntu users.
# deb http://archive.canonical.com/ubuntu zesty partner
# deb-src http://archive.canonical.com/ubuntu zesty partner

# deb http://security.ubuntu.com/ubuntu zesty-security main restricted
# deb http://security.ubuntu.com/ubuntu zesty-security main restricted
# deb http://security.ubuntu.com/ubuntu zesty-security universe
# deb http://security.ubuntu.com/ubuntu zesty-security universe
# deb http://security.ubuntu.com/ubuntu zesty-security multiverse
# deb http://security.ubuntu.com/ubuntu zesty-security multiverse
EOF

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
