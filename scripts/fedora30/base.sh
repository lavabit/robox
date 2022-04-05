#!/bin/bash

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "nameserver 4.2.2.1\nnameserver 4.2.2.2\nnameserver 208.67.220.220\n"> /etc/resolv.conf

# Ensure memcached doesn't try to use IPv6.
if [ -f /etc/sysconfig/memcached ]; then
  sed -i "s/[,]\?\:\:1[,]\?//g" /etc/sysconfig/memcached
fi

# Enable and start the daemons.
systemctl enable haveged
systemctl enable memcached
systemctl start haveged
systemctl start memcached

# Disable IPv6 and the iptables module used to firewall IPv6.
printf "\n\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

sed -i -e "/IPV6INIT.*/d;$ a IPV6INIT=no" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "/IPV6_AUTOCONF.*/d;$ a IPV6_AUTOCONF=no" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "/IPV6_DEFROUTE.*/d;$ a IPV6_DEFROUTE=no" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "/IPV6_PEERDNS.*/d;$ a IPV6_PEERDNS=no" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "/IPV6_PEERROUTES.*/d;$ a IPV6_PEERROUTES=no" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "/IPV6FORWARDING.*/d;$ a IPV6FORWARDING=no" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "/IPV6_AUTOTUNNEL.*/d;$ a IPV6_AUTOTUNNEL=no" /etc/sysconfig/network-scripts/ifcfg-eth0


# Ensure good DNS servers are being used.
if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
  printf "DNS1=4.2.2.1\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  printf "DNS2=4.2.2.2\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
fi

# Close a potential security hole.
systemctl disable remote-fs.target

# Disable kernel dumping.
# systemctl disable kdump.service

# Setup the python path and increase the history size.
printf "export HISTSIZE=\"100000\"\n" > /etc/profile.d/histsize.sh
chcon "system_u:object_r:bin_t:s0" /etc/profile.d/histsize.sh
chmod 644 /etc/profile.d/histsize.sh

# Reboot
( shutdown --reboot --no-wall +1 ) &
exit 0

