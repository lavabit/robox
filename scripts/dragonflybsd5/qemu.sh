#!/bin/bash -eux

# Configure fetch so it retries temporary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Ensure dmideocode is available.
pkg-static install --yes dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
    exit 0
fi

# Load the virtio module at boot.
echo 'if_vtnet_load="YES"' >> /boot/loader.conf
echo 'virtio_load="YES"' >> /boot/loader.conf
echo 'virtio_pci_load="YES"' >> /boot/loader.conf
echo 'virtio_blk_load="YES"' >> /boot/loader.conf
echo 'virtio_scsi_load="YES"' >> /boot/loader.conf
echo 'virtio_console_load="YES"' >> /boot/loader.conf
echo 'virtio_balloon_load="YES"' >> /boot/loader.conf
echo 'virtio_random_load="YES"' >> /boot/loader.conf

# Enable the daemons used for host to geust communication.
printf "rpcbind_enable=\"YES\"\n" >> /etc/rc.conf
printf "nfsclient_enable=\"YES\"\n" >> /etc/rc.conf
