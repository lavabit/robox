#!/bin/bash -eux

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^generic-devuan4-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "devuan4.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 devuan4.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi

# Tne network interface and DHCP client are configured by the installer
# via the preseed config, to avoid IP address changes during a reboot.
(sleep 30 ; /sbin/reboot) &
echo "Rebooting in thirty seconds..."
exit 0
