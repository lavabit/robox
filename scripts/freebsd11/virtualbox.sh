#!/bin/bash -eux

# Ensure dmideocode is available.
pkg-static install --yes dmidecode

# Bail if we are not running inside VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

pkg-static install -y virtualbox-ose-additions

sysrc ifconfig_em1="inet 10.6.66.42 netmask 255.255.255.0"
sysrc vboxguest_enable="YES"
sysrc vboxservice_flags="--disable-timesync"
sysrc vboxservice_enable="YES"

sysrc rpcbind_enable="YES"
sysrc rpc_lockd_enable="YES"
sysrc nfs_client_enable="YES"
