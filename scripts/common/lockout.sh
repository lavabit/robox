#!/bin/bash -eux

# Randomize the root password and then lock the root account.
dd if=/dev/urandom count=50 | md5sum | passwd --stdin root
passwd -l root
