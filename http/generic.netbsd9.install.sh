#!/bin/sh

# We don't know what type of device this hypervisor might be using, so we
# just keep trying till we are able to mount something.
(mount /dev/sd0a /mnt || mount /dev/wd0a /mnt) || mount /dev/dk0 /mnt

sed -i 's/^#UseDNS no/UseDNS no/' /mnt/etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /mnt/etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /mnt/etc/ssh/sshd_config

printf "sshd=YES\n" >> /mnt/etc/rc.conf
printf "dhcpcd=YES\n" >> /mnt/etc/rc.conf
printf "ntpdate=YES\n" >> /mnt/etc/rc.conf

# On networks without IPv6 support, NetBSD guests will autoconfigure an invalid route, and try to use
# the invalid route, before timing out and falling back to IPv4. These settings mitigate the performance
# impact.
# https://www.netbsd.org/docs/guide/en/netbsd.html#chap-virt-guest-ipv6
# https://web.archive.org/web/20211223010333/http://www.netbsd.org/docs/guide/en/netbsd.html#chap-virt-guest-ipv6
printf "ip6addrctl=YES\n" >> /mnt/etc/rc.conf
printf "ip6addrctl_policy=\"ipv4_prefer\"\n" >> /mnt/etc/rc.conf

