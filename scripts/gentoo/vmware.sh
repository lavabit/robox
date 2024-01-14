#!/bin/bash

emerge sys-apps/dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# VMWare NAT configurations don't work with the latest version of OpenSSH (currently v7.7),
# so we force emerge to use install OpenSSH v7.5. If you want to use the latest version of
# OpenSSH, set ssh_info_public as true in VMWare provider section of the Vagrantfile.
cat <<-EOF > /etc/portage/package.mask/openssh
>=net-misc/openssh-7.6
EOF

cat <<-EOF > /etc/portage/package.unmask/openssh
=net-misc/openssh-7.5
EOF

USE="-X -resolutionkms icu pam ssl fuse vgauth xml-security-c grabbitmqproxy python_targets_python3_6" emerge --ask=n --autounmask-write=y --autounmask-continue=y app-emulation/open-vm-tools net-misc/openssh

# Perform any configuration file updates.
etc-update --automode -5

if [ "$(which rc-update 2>/dev/null)" ]; then
  rc-update add vmware-tools default
  rc-service vmware-tools start
else
  systemctl enable vmtoolsd.service
  systemctl start vmtoolsd.service
fi

rm --force /root/linux.iso

# Fix the SSH NAT issue on VMWare systems.
printf "\nIPQoS lowdelay throughput\n" >> /etc/ssh/sshd_config
