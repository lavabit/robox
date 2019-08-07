#!/bin/bash -eux

# Update the base install first.
dnf --assumeyes update

# The basic utilities we'd expect to find.
dnf --assumeyes install net-tools yum-utils bash-completion man-pages vim-enhanced mlocate sysstat bind-utils wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl psmisc tar

# Schedule a reboot, but give the computer time to cleanly shutdown the
# network interface first.
shutdown --reboot --no-wall +1
