#!/bin/bash

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "nameserver 4.2.2.1\nnameserver 4.2.2.2\nnameserver 208.67.220.220\nnameserver 208.67.222.222\n"> /etc/resolv.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^generic-centos7-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "centos7.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 centos7.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi

# Disable IPv6 or yum will resolve mirror names to IPv6 address and then fail to connect with them.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Disable IPv6 and the iptables module used to firewall IPv6.
printf "\n\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

sed -i -e "s/IPV6INIT=yes/IPV6INIT=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_AUTOCONF=yes/IPV6_AUTOCONF=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_DEFROUTE=yes/IPV6_DEFROUTE=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_PEERDNS=yes/IPV6_PEERDNS=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_PEERROUTES=yes/IPV6_PEERROUTES=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0

# If postfix is installed, configure it use only ipv4 interfaces, or it will fail to start properly.
if [ -f /etc/postfix/main.cf ]; then
  sed -i "s/^inet_protocols.*$/inet_protocols = ipv4/g" /etc/postfix/main.cf
fi

# Works around a bug which slows down DNS queries on Virtualbox.
# https://access.redhat.com/site/solutions/58625

# Bail if we are not running atop VirtualBox.
if [[ "$PACKER_BUILDER_TYPE" != virtualbox-iso ]]; then
    exit 0
fi

printf "Fixing the problem with slow DNS queries.\n"

cat >> /etc/NetworkManager/dispatcher.d/fix-slow-dns <<EOF
#!/bin/bash
echo "options single-request-reopen" >> /etc/resolv.conf
EOF

chmod +x /etc/NetworkManager/dispatcher.d/fix-slow-dns
systemctl restart NetworkManager.service
