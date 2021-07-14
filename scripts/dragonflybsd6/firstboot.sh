#!/bin/bash -eux

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

pkg-static install -y firstboot-pkgs firstboot-growfs

sysrc firstboot-growfs=YES
sysrc firstboot_pkgs=YES

# Tell the system the next boot will be the first boot.
touch /firstboot
