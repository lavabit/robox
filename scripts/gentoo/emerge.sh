#!/bin/bash -ux

# Force python updates for this system.
# cat <<EOF >> "/etc/portage/package.unmask/python-2.7"
# =dev-lang/python-2.7.5*
# EOF

# Update the package database.
emerge --sync

# This will update portage - if necessary.
emerge --oneshot portage

# Update the system packages.
emerge --update --deep --newuse --with-bdeps=y @world

# Useful tools.
emerge app-editors/vim net-misc/curl net-misc/wget sys-apps/mlocate app-admin/sysstat app-admin/rsyslog sys-apps/lm_sensors sys-process/lsof app-admin/sudo net-misc/ssh-askpass-fullscreen

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Start the syslog service.
rc-update add rsyslog default && rc-service rsyslog start

# Start the services we just added so the system will track its own performance.
rc-update add sysstat default && rc-service sysstat start

# This will ensure sensors get initialized during the boot process.
rc-update add lm_sensors default && rc-service lm_sensors start

# Configure the lm_sensors.conf file.
/usr/sbin/sensors-detect

# Create an initial mlocate database.
updatedb

reboot
