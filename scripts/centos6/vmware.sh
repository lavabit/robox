#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nvmware install failed...\n\n";
                exit 1
        fi
}


# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# Install the VMWare Tools.
printf "Installing the VMWare Tools.\n"

# The developer desktop builds need the desktop tools/drivers.
if [[ "$PACKER_BUILD_NAME" =~ ^magma-developer-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  yum --quiet --assumeyes install open-vm-tools open-vm-tools-desktop fuse-libs libdnet libicu libmspack
else
  yum --quiet --assumeyes install open-vm-tools fuse-libs libdnet libicu libmspack
fi

chkconfig vmtoolsd on
service vmtoolsd start

#mkdir -p /mnt/vmware; error
#mount -o loop /root/linux.iso /mnt/vmware; error

#cd /tmp; error
#tar xzf /mnt/vmware/VMwareTools-*.tar.gz; error

#umount /mnt/vmware; error
rm -rf /root/linux.iso; error

#/tmp/vmware-tools-distrib/vmware-install.pl -d; error
#rm -rf /tmp/vmware-tools-distrib; error
