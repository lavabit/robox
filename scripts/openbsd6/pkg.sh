#!/bin/sh

# Setup a package mirror.
echo "https://ftp.usa.openbsd.org/pub/OpenBSD/" > /etc/installurl

# Update the system.
pkg_add -u

# Install a few basic tools.
pkg_add -I curl wget bash sudo-- vim--no_x11

# Since most scripts expect bash to be in the bin directory, create a symlink.
ln -s /usr/local/bin/bash /bin/bash

# Some hypervisors require this to run OpenBSD properly.
echo "kern.allowkmem=1" > /etc/sysctl.conf

# Reboot gracefully.
shutdown -r +1 &
