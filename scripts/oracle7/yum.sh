#!/bin/bash -eux

# Update the base install first.
yum --assumeyes update

# The basic utilities we'd expect to find.
yum --assumeyes install man git sudo lsof wget curl telnet mlocate sysstat dmidecode bind-utils yum-utils vim-enhanced net-tools deltarpm

# Remove the stray rpm save file.
mv --force /etc/nsswitch.conf.rpmnew /etc/nsswitch.conf

# Update the locate database.
/etc/cron.daily/mlocate.cron

# Schedule a reboot, but give the computer time to cleanly shutdown the
# network interface first.
shutdown --reboot --no-wall +1
