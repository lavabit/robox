#!/bin/bash

# Disable IPv6 for the current boot.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure IPv6 stays disabled.
printf "\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^generic-ubuntu1810-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "ubuntu1810.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 ubuntu1810.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi

# This will ensure the network device is named eth0.
sed -i -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.ifnames=0"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

cat <<-EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      nameservers:
        addresses: [8.8.8.8, 4.2.2.2]
EOF

# Apply the network plan configuration.
netplan generate

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
sed -i -e "s/#DNS=/DNS=8.8.8.8 4.2.2.2/g" /etc/systemd/resolved.conf
sed -i -e "s/#FallbackDNS=/FallbackDNS=/g" /etc/systemd/resolved.conf
sed -i -e "s/#Domains=/Domains=/g" /etc/systemd/resolved.conf

# Ensure the networking interfaces get configured on boot.
systemctl enable systemd-networkd.service
