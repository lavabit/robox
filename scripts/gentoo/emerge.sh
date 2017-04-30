#!/bin/bash -ux

# Update the package database.
emerge --sync --noconfirm

# Update the system packages.
emerge --update --deep --with-bdeps=y @world

# Useful tools.
emerge app-editors/vim net-misc/curl  net-misc/wget sys-apps/mlocate  app-admin/sysstat  sys-apps/lm_sensors  sys-process/lsof app-admin/sudo

# Start the services we just added so the system will track its own performance.
rc-update add sysstat default && rc-service sysstat default

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

reboot
