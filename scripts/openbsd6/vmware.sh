#!/bin/bash -eux

# Ensure dmideocode is available.
pkg_add -I dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

rm -f /root/freebsd.iso

# Fix the SSH NAT issue on VMWare systems.
printf "\nIPQoS lowdelay throughput\n" >> /etc/ssh/sshd_config
