#!/bin/bash

printf "Rebooting onto the newly installed kernel of popcorn. Yummy.\n"

# Schedule a reboot, but give the computer time to cleanly shutdown the
# network interface first.
( shutdown --reboot --no-wall +1 ) &
exit 0

