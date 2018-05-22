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
printf "Installing the VMWare Tools.\n"

apt-get --assume-yes --ignore-missing install open-vm-tools ethtool libdumbnet1 zerofree
systemctl enable open-vm-tools.service
systemctl start open-vm-tools.service

#mkdir -p /mnt/vmware; error
#mount -o loop /root/linux.iso /mnt/vmware; error

#cd /tmp; error
#tar xzf /mnt/vmware/VMwareTools-*.tar.gz; error

#umount /mnt/vmware; error
rm -rf /root/linux.iso; error

#/tmp/vmware-tools-distrib/vmware-install.pl -d; error
#rm -rf /tmp/vmware-tools-distrib; error

# Boosts the available entropy which allows magma to start faster.
apt-get --assume-yes --ignore-missing install haveged; error

# Autostart the haveged daemon.
systemctl enable haveged.service
