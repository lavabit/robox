#!/bin/bash -eux

# Update the package database.
pacman --sync --noconfirm --refresh

# Update the system packages.
pacman --sync --noconfirm --refresh --sysupgrade

# Useful tools.
pacman --sync --noconfirm vim vim-runtime curl wget mlocate sysstat lm_sensors lsof psmisc

# Start the services we just added so the system will track its own performance.
systemctl enable sysstat.service && systemctl start sysstat.service

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Reboot onto the new kernel (if applicable).
reboot
