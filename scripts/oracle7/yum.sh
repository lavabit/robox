#!/bin/bash -eux

# Update the base install first.
yum --assumeyes update

# The basic utilities we'd expect to find.
yum --assumeyes install deltarpm net-tools yum-utils bash-completion man-pages vim-enhanced mlocate sysstat bind-utils jwhois wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl psmisc

# Update the locate database.
/etc/cron.daily/mlocate.cron

# Schedule a reboot, but give the computer time to cleanly shutdown the
# network interface first.
shutdown --reboot --no-wall +1
