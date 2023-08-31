#!/bin/bash -eux

# Ensure the network shuts down properly.
printf 'keep_network="NO"\n' >> /etc/rc.conf

# Ensure SSHD waits until the network is up and running before launching.
printf 'rc_need="net-online"\n' >> /etc/conf.d/sshd

# Set up the required interfaces.
printf 'interfaces="eth0"\n' >> /etc/conf.d/net-online
printf 'timeout=120\n' >> /etc/conf.d/net-online

# Enable the net-online target.
rc-update add net-online default
rc-update -u

