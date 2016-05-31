#!/bin/bash

# Zerofill the empty space to make the final image more efficient.
printf "\n\n\nZerofill the empty space.\n"
dd if=/dev/zero of=/zerofill bs=1M
sync
rm --force /zerofill

# Sync to ensure that the delete completes before we move to the shutdown phase.
sync
sync
sync
