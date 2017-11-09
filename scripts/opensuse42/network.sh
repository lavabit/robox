#!/bin/bash -eux

# Make sure Udev doesn't block our network
printf "Cleaning up udev rules.\n"
rm /etc/udev/rules.d/70-persistent-net.rules
mkdir /etc/udev/rules.d/70-persistent-net.rules
