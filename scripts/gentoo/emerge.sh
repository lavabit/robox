#!/bin/bash -ux

# Wipe and then update the package database.
rm --recursive --force /usr/portage/
mkdir /usr/portage/
emerge-webrsync

# Update portage.
emerge --oneshot sys-apps/portage

# Update the system packages.
emerge --ask=n --autounmask-write=y --autounmask-continue=y --update --deep --newuse --with-bdeps=y @system @world

# Useful tools.
USE="-X pam_ssh tty-helpers openssl" emerge --ask=n --autounmask-write=y --autounmask-continue=y app-admin/rsyslog app-admin/sudo app-admin/sysstat app-arch/bzip2 app-arch/bzip2 app-arch/gzip app-arch/gzip app-arch/tar app-arch/xz-utils app-editors/vim app-shells/bash dev-libs/lzo net-misc/curl net-misc/iputils net-misc/openssh net-misc/wget sys-apps/baselayout sys-apps/coreutils sys-apps/diffutils sys-apps/file sys-apps/findutils sys-apps/gawk sys-apps/grep sys-apps/kbd sys-apps/less sys-apps/lm-sensors sys-apps/man-pages sys-apps/mlocate sys-apps/net-tools sys-apps/openrc sys-apps/sed sys-apps/util-linux sys-apps/which sys-apps/which sys-auth/pambase sys-auth/pam_ssh sys-libs/glibc sys-libs/pam sys-process/lsof sys-process/procps sys-process/psmisc net-misc/rsync

# Perform any configuration file updates.
etc-update --automode -5

# If the OpenSSH config gets updated, we need to preserve our settings.
sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config

# Clear the news feed.
eselect news read --quiet

# Remove obsolete dependencies.
emerge --depclean

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Configure the lm_sensors.conf file.
/usr/sbin/sensors-detect --auto

# Enable/apply configuration file updates.
etc-update --automode -5

# Start the syslog service.
if [ "$(which rc-update 2>/dev/null)" ]; then
  rc-update add rsyslog default && rc-service rsyslog start
  rc-update add sysstat default && rc-service sysstat start
  (rc-service lm_sensors start && rc-update add lm_sensors default) || rc-update delete lm_sensors default
else
  systemctl enable rsyslog.service && systemctl start rsyslog.service
  systemctl enable sysstat.service && systemctl start sysstat.service
  (systemctl enable lm_sensors.service && systemctl start lm_sensors.service) || systemctl disable lm_sensors.service
fi

# Create an initial mlocate database.
updatedb

( sleep 60 ; reboot ) &
exit 0

