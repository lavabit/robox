#!/bin/sh

echo "https://ftp.usa.openbsd.org/pub/OpenBSD/" > /etc/installurl
pkg_add -I curl wget bash sudo-- vim--no_x11

echo "kern.allowkmem=1" > /etc/sysctl.conf
reboot
