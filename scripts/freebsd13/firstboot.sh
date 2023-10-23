#!/bin/bash -eux

# Configure fetch so it retries temporary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Uncomment to Enable automatic updating during the first boot.
# pkg add -i firstboot_freebsd_update
# sysrc firstboot_freebsd_update=NO

pkg-static install -y firstboot-pkgs

sysrc firstboot_growfs_enable=YES
sysrc firstboot_pkgs_enable=YES

# Tell the system the next boot will be the first boot.
touch /firstboot
