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

# Install the VMWare Tools from the Linux ISO.
printf "\n\nInstalling the VMWare Tools.\n"

mkdir -p /mnt/vmware; error
mount -o loop /root/linux.iso /mnt/vmware; error

cd /tmp; error
tar xzf /mnt/vmware/VMwareTools-*.tar.gz; error

umount /mnt/vmware; error
rm -rf /root/linux.iso; error

/tmp/vmware-tools-distrib/vmware-install.pl -d; error
rm -rf /tmp/vmware-tools-distrib; error

echo 'add_drivers+=" mptspi "' > /etc/dracut.conf.d/vmware-drivers.conf
restorecon -f /etc/dracut.conf.d/vmware-drivers.conf
# Rerun dracut for the installed kernel (not the running kernel):
KERNEL_VERSION=$(rpm -q kernel --qf '%{version}-%{release}.%{arch}\n')
dracut -f /boot/initramfs-${KERNEL_VERSION}.img ${KERNEL_VERSION}
