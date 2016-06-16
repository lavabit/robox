#!/bin/bash

printf "\n\nCleanup stage.\n\n"

# Make sure the ethnernet configuration script doesn't retain identifiers.
printf "Remove the ethernet identity values.\n"
sed -i /UUID/d /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i /HWADDR/d /etc/sysconfig/network-scripts/ifcfg-eth0

# Make sure Udev doesn't block our network
printf "Cleaning up udev rules.\n"
rm /etc/udev/rules.d/70-persistent-net.rules
mkdir /etc/udev/rules.d/70-persistent-net.rules

# Clean up the yum data.
printf "Remove packages only required for provisioning purposes and then dump the repository cache.\n"
yum --assumeyes remove dmidecode yum-utils
yum --assumeyes clean all

# Remove the installation logs.
rm --force /root/anaconda-ks.cfg /root/install.log /root/install.log.syslog

# Truncate the log files.
printf "Truncate the log files.\n"
find /var/log -type f -exec truncate --size=0 {} \;

# Wipe the temp directory.
printf "Purge the temporary data files.\n"
rm --recursive --force /var/tmp/* /tmp/*



