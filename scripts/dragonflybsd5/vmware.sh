#!/bin/bash -eux

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Ensure dmideocode is available.
pkg-static install --yes dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# Dpownload the FreeBSD package beacause Dragonfly doesn't have one.
curl -o open-vm-tools-nox11-10.3.0.txz https://pkg.freebsd.org/FreeBSD:11:amd64/quarterly/All/open-vm-tools-nox11-10.3.0,2.txz

# Fuse libraries are required.
pkg-static install --yes fuse fuse-utils

pkg-static install --yes open-vm-tools-nox11-10.3.0.txz

printf "vmware_guest_vmblock_enable=\"YES\"\n" >> /etc/rc.conf
printf "vmware_guest_vmhgfs_enable=\"YES\"\n" >> /etc/rc.conf
printf "vmware_guest_vmmemctl_enable=\"YES\"\n" >> /etc/rc.conf
printf "vmware_guest_vmxnet_enable=\"YES\"\n" >> /etc/rc.conf
printf "vmware_guestd_enable=\"YES\"\n" >> /etc/rc.conf

printf "rpcbind_enable=\"YES\"\n" >> /etc/rc.conf
printf "nfsclient_enable=\"YES\"\n" >> /etc/rc.conf

rm -f  open-vm-tools-nox11-10.3.0.txz
rm -f /root/freebsd.iso
