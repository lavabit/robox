#!/bin/sh

echo "https://ftp.usa.openbsd.org/pub/OpenBSD/" > /etc/installurl
pkg_add -I curl wget bash sudo-- vim--no_x11

# Since most scripts expect bash to be in the bin directory, create a symlink.
ln -s /usr/local/bin/bash /bin/bash

echo "kern.allowkmem=1" > /etc/sysctl.conf
reboot
