#!/bin/bash -eux

# Ensure dmidecode is available.
apk add dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# Install the VMWare Tools from the Linux ISO.
printf "Installing the VMWare Tools.\n"

# Add the community repository.
printf "@community https://dl-3.alpinelinux.org/alpine/v3.6/community\n@community https://mirror.leaseweb.com/alpine/v3.6/community\n" >> /etc/apk/repositories

# Update the APK cache.
apk update

# Install the Open VMWare Tools.
# apk add open-vm-tools

# Autostart the open-vm-tools.
# rc-update add open-vm-tools default && rc-service open-vm-tools start

# Boosts the available entropy which allows magma to start faster.
apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start

# The VMWare tool dependencies.
apk add perl build-base

mkdir /etc/rc.d/
ln -s /etc/runlevels/boot/ /etc/rc.d/rc0.d
ln -s /etc/runlevels/boot/ /etc/rc.d/rc1.d
ln -s /etc/runlevels/sysinit/ /etc/rc.d/rc2.d
ln -s /etc/runlevels/nonetwork/ /etc/rc.d/rc3.d
ln -s /etc/runlevels/default/ /etc/rc.d/rc4.d
ln -s /etc/runlevels/default/ /etc/rc.d/rc5.d
ln -s /etc/runlevels/shutdown/ /etc/rc.d/rc6.d
sleep 600
# Uncomment if you'd prefer to build the guest additions from source.
mkdir -p /media/vmware
mount -o loop /root/linux.iso /media/vmware
cd /tmp
tar xzf /media/vmware/VMwareTools-*.tar.gz
/tmp/vmware-tools-distrib/vmware-install.pl -d
rm -rf /tmp/vmware-tools-distrib
umount /media/vmware
rmdir /media/vmware

# When we're done delete the tools ISO.
rm -rf /root/linux.iso
