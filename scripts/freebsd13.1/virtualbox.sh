#!/bin/bash -eux

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Ensure dmideocode is available.
pkg-static install --yes dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the virtualbox guest additions.
pkg-static install --yes virtualbox-ose-additions-nox11

# Load the virtio module at boot.
echo 'if_vtnet_load="YES"' >> /boot/loader.conf
echo 'virtio_load="YES"' >> /boot/loader.conf
echo 'virtio_pci_load="YES"' >> /boot/loader.conf
echo 'virtio_blk_load="YES"' >> /boot/loader.conf
echo 'virtio_scsi_load="YES"' >> /boot/loader.conf
echo 'virtio_console_load="YES"' >> /boot/loader.conf
echo 'virtio_balloon_load="YES"' >> /boot/loader.conf
echo 'virtio_random_load="YES"' >> /boot/loader.conf

sysrc ifconfig_em1="inet 10.6.66.42 netmask 255.255.255.0"
sysrc vboxguest_enable="YES"
sysrc vboxservice_enable="YES"

sysrc rpcbind_enable="YES"
sysrc rpc_lockd_enable="YES"
sysrc nfs_client_enable="YES"

rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso
