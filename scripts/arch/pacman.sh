#!/bin/bash -eux

# Update the package database.
pacman --sync --noconfirm --refresh

# Update the system packages.
pacman --sync --noconfirm --refresh --sysupgrade

# Useful tools.
pacman --sync --noconfirm --refresh vim curl wget sysstat lsof psmisc man-db mlocate net-tools lm_sensors vim-runtime

# Start the services we just added so the system will track its own performance.
systemctl enable sysstat.service && systemctl start sysstat.service

# Ensure the daily update timers are enabled.
systemctl enable man-db.timer
systemctl enable updatedb.timer

# Initialize the databases.
updatedb
mandb

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Reboot onto the new kernel (if applicable).
reboot
