#!/bin/bash

printf "Cleanup stage.\n"

# Make sure the ethnernet configuration script doesn't retain identifiers.
printf "Remove the ethernet identity values.\n"
sed -i /uuid/d /etc/NetworkManager/system-connections/eth0.nmconnection

# Clean up the dnf data.
printf "Remove packages only required for provisioning purposes and then dump the repository cache.\n"
dnf --assumeyes clean all

# Remove the installation logs.
rm --recursive --force /root/anaconda-ks.cfg /root/install.log /root/install.log.syslog /var/log/yum.log /var/log/anaconda*

# Clear the random seed.
rm -f /var/lib/systemd/random-seed

# Truncate the log files.
printf "Truncate the log files.\n"
find /var/log -type f -exec truncate --size=0 {} \;

# Wipe the temp directory.
printf "Purge the setup files and temporary data.\n"
rm --recursive --force /var/tmp/* /tmp/* /var/cache/dnf/* /tmp/ks-script*

# Clear the command history.
export HISTSIZE=0

exit 0
