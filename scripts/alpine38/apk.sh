#!/bin/sh -eux

# Configure the main repository mirrors.
printf "https://mirror.leaseweb.com/alpine/v3.8/main\n" > /etc/apk/repositories

# Update the package list and then upgrade.
apk update --no-cache
apk update upgrade

# Install various basic system utilities.
apk add vim man man-pages bash gawk wget curl sudo lsof file grep readline mdocml sysstat lm_sensors findutils sysfsutils dmidecode libmagic sqlite-libs ca-certificates ncurses-libs ncurses-terminfo ncurses-terminfo-base

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Make the shell bash, instead of ash.
sed -i -e "s/\/bin\/ash/\/bin\/bash/g" /etc/passwd

# Run the updatedb script so the locate command works.
updatedb

# Reboot onto the new kernel (if applicable).
reboot
