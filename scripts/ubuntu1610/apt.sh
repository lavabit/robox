#!/bin/bash

# Use the Lavabit mirror.
sed -i -e "s/http:\/\/old-releases.ubuntu.com/https:\/\/mirrors.lavabit.com/g" /etc/apt/sources.list

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive

# Disable upgrades to new releases.
sed -i -e 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades;

# Disable periodic activities of apt
printf "APT::Periodic::Enable \"0\";\n" >> /etc/apt/apt.conf.d/10periodic

# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer
systemctl stop snapd.service snapd.socket snapd.refresh.timer

# Update the package database.
apt-get --assume-yes -o Dpkg::Options::="--force-confnew" update

# Ensure the linux-tools and linux-cloud-tools get updated with the kernel.
apt-get --assume-yes -o Dpkg::Options::="--force-confnew" install linux-tools-generic linux-cloud-tools-generic

# Upgrade the installed packages.
apt-get --assume-yes -o Dpkg::Options::="--force-confnew" upgrade
apt-get --assume-yes -o Dpkg::Options::="--force-confnew" dist-upgrade

# Needed to retrieve source code, and other misc system tools.
apt-get --assume-yes install vim vim-nox git git-man liberror-perl wget curl rsync gnupg mlocate sysstat lsof pciutils usbutils lsb-release

# Enable the sysstat collection service.
sed -i -e "s|.*ENABLED=\".*\"|ENABLED=\"true\"|g" /etc/default/sysstat

# Start the services we just added so the system will track its own performance.
systemctl enable sysstat.service && systemctl start sysstat.service

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Reboot onto the new kernel (if applicable).
reboot
