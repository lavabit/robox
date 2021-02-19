#!/bin/bash -eux

# Fix the UUID bug.
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=852323

/usr/sbin/update-grub
