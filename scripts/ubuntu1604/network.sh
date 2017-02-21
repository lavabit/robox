#!/bin/bash -eux

# Disable IPv6 or yum will resolve mirror names to IPv6 address and then fail to connect with them.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "\nnameserver 4.2.2.1\n" > /etc/resolv.conf

# Set the local hostname to resolve properly.
printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts

# Setup the hostname.
printf "magma.builder\n" > /etc/hostname
