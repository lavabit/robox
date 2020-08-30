#!/bin/bash

printf "Cleanup stage.\n"

# Make sure the ethnernet configuration script doesn't retain identifiers.
printf "Remove the ethernet identity values.\n"
sed -i /UUID/d /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i /HWADDR/d /etc/sysconfig/network-scripts/ifcfg-eth0

# Clean up the yum data.
printf "Purge the repository cache.\n"
yum --quiet --assumeyes clean all

# Purge the pip cache.
rm --force --recursive /root/.cache/

# Remove the installation logs.
rm --force /root/anaconda-ks.cfg /root/original-ks.cfg /root/install.log /root/install.log.syslog

# Clear the command history.
export HISTSIZE=0

# Truncate the log files.
printf "Truncate the log files.\n"
find /var/log -type f -exec truncate --size=0 {} \;

# Wipe the temp directory.
printf "Purge the setup files and temporary data.\n"
rm --recursive --force /var/tmp/* /tmp/* /var/cache/yum/* /tmp/ks-script*
