#!/bin/bash -eux

# Delete the DHCP client lease files from any/all locations we know about.

if [ -d /var/lib/NetworkManager/ ]; then
  find /var/lib/NetworkManager/ -name "*.lease" -or -name "*.leases"
  find /var/lib/NetworkManager/ -name "*.lease" -or -name "*.leases" -exec rm --force {} \;
fi

if [ -d /var/lib/dhclient/ ]; then
  find /var/lib/dhclient/ -name "*.lease" -or -name "*.leases"
  find /var/lib/dhclient/ -name "*.lease" -or -name "*.leases" -exec rm --force {} \;
fi

if [ -d /var/lib/dhcp/ ]; then
  find /var/lib/dhcp/ -name "*.lease" -or -name "*.leases"
  find /var/lib/dhcp/ -name "*.lease" -or -name "*.leases" -exec rm --force {} \;
fi
