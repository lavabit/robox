#!/bin/bash -ux

# Force python updates for this system.
cat <<EOF >> "/etc/portage/package.unmask/python-3.6"
=dev-lang/python-3.6
EOF

cat <<EOF >> "/etc/portage/package.unmask/python-2.7"
=dev-lang/python-2.7
EOF

# Update the package database.
emerge --sync

# Useful tools.
emerge --ask=n --autounmask-continue=y sys-apps/coreutils app-editors/vim net-misc/curl net-misc/wget sys-apps/mlocate app-admin/sysstat app-admin/rsyslog sys-apps/lm_sensors sys-process/lsof app-admin/sudo net-misc/openssh net-misc/openssh-blacklist net-libs/libssh net-libs/libssh2 net-misc/autossh net-misc/sshpass sys-apps/util-linux sys-apps/portage sys-apps/gawk sys-apps/man-pages sys-apps/sed sys-apps/findutils sys-apps/diffutils app-portage/portage-utils sys-apps/baselayout sys-apps/net-tools app-shells/bash app-arch/bzip2 app-arch/xz-utils sys-apps/which app-arch/gzip sys-apps/file sys-apps/less app-arch/tar net-misc/iputils sys-process/psmisc sys-apps/openrc app-admin/sudo sys-apps/grep sys-process/procps sys-apps/kbd sys-libs/glibc sys-libs/pam sys-auth/pam_ssh sys-auth/pambase sys-auth/pam_skey sys-auth/pam_p11 sys-auth/pam_passwdqc sys-auth/pam_mktemp sys-auth/pam_dotfile sys-auth/pam_fprint

# Update the system packages.
emerge --update --deep --newuse --with-bdeps=y @system @world

# Remove obsolete dependencies.
# emerge --depclean

# Clear the news feed.
eselect news read --quiet

# Perform any configuration file updates.
etc-update --automode -5

# If the OpenSSH config gets updated, we need to preserve our settings.
sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Configure the lm_sensors.conf file.
/usr/sbin/sensors-detect --auto

# Start the syslog service.
rc-update add rsyslog default && rc-service rsyslog start

# Start the services we just added so the system will track its own performance.
rc-update add sysstat default && rc-service sysstat start

# This will ensure sensors get initialized during the boot process.
rc-update add lm_sensors default && rc-service lm_sensors start

# Create an initial mlocate database.
updatedb

reboot
