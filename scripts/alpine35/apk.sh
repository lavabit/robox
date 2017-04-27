#!/bin/sh

# Update the package list and then upgrade.
apk update --force
apk update --force upgrade

# Install various basic system utilities.
apk add --force vim man bash wget curl sudo lsof readline mdocml sysstat lm_sensors sysfsutils dmidecode sqlite-libs ca-certificates ncurses-libs ncurses-terminfo ncurses-terminfo-base

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Reboot onto the new kernel (if applicable).
reboot
