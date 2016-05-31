#!/bin/bash

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# Install the VMWare Tools from the Linux ISO.
printf "\n\nInstalling the VMWare Tools.\n"

mkdir -p /mnt/vmware
mount -o loop /root/linux.iso /mnt/vmware

cd /tmp
tar xzf /mnt/vmware/VMwareTools-*.tar.gz

umount /mnt/vmware
rm -rf /root/linux.iso

/tmp/vmware-tools-distrib/vmware-install.pl -d
rm -rf /tmp/vmware-tools-distrib
