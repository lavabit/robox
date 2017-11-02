#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\napt failed...\n\n";
                exit 1
        fi
}

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive

# Disable upgrades to new releases.
sed -i -e 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades;

# Disable periodic activities of apt
printf "APT::Periodic::Enable \"0\";\n" >> /etc/apt/apt.conf.d/10periodic

# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer
systemctl stop snapd.service snapd.socket snapd.refresh.timer

# Update the package list and then upgrade.
apt-get --assume-yes update; error
apt-get --assume-yes upgrade; error
apt-get --assume-yes dist-upgrade; error
apt-get --assume-yes full-upgrade; error

# Fix DNS resolution errors.
rm --force /etc/resolv.conf
ln --symbolic /run/resolvconf/resolv.conf /etc/resolv.conf
systemctl restart resolvconf

printf "\n\n\n\nbegin resolv.conf\n\n"
cat /etc/resolv.conf
printf "\n\n\n\nend resolv.conf\n\n"

# Needed to retrieve source code, and other misc system tools.
apt-get --assume-yes install vim vim-nox git git-man liberror-perl wget curl rsync gnupg mlocate sysstat lsof pciutils usbutils; error

# Enable the sysstat collection service.
sed -i -e "s|.*ENABLED=\".*\"|ENABLED=\"true\"|g" /etc/default/sysstat

# Start the services we just added so the system will track its own performance.
systemctl enable sysstat.service && systemctl start sysstat.service

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Reboot onto the new kernel (if applicable).
reboot
