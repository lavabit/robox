#!/bin/bash -x

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "nameserver 4.2.2.1\nnameserver 4.2.2.2\nnameserver 208.67.220.220\n" > /etc/resolv.conf

# Disable IPv6 or yum will resolve mirror names to IPv6 address and then fail to connect with them.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Disable IPv6 and the iptables module used to firewall IPv6.
printf "\n\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^generic-(oracle|oracle6)-(vmware|hyperv|docker|libvirt|parallels|virtualbox)$ ]]; then
  sed -i -e "/HOSTNAME/d" /etc/sysconfig/network
  printf "HOSTNAME=oracle6.localdomain\n" >> /etc/sysconfig/network

  if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
    sed -i -e "/DHCP_HOSTNAME/d" /etc/sysconfig/network-scripts/ifcfg-eth0
    printf "DHCP_HOSTNAME=\"oracle6.localdomain\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  fi

  printf "\n127.0.0.1 oracle6.localdomain\n\n" >> /etc/hosts

else
  sed -i -e "/HOSTNAME/d" /etc/sysconfig/network
  printf "HOSTNAME=magma.localdomain\n" >> /etc/sysconfig/network

  if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
    sed -i -e "/DHCP_HOSTNAME/d" /etc/sysconfig/network-scripts/ifcfg-eth0
    printf "DHCP_HOSTNAME=\"magma.localdomain\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  fi

  printf "\n127.0.0.1 magma.localdomain\n\n" >> /etc/hosts

fi

if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then

  sed -i -e "/ONBOOT/d" /etc/sysconfig/network-scripts/ifcfg-eth0
  printf "ONBOOT=\"yes\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0

  # Let the network configuration utilities know we don't want IPv6 configured.
  sed -i -e "/IPV6INIT.*/d;$ a IPV6INIT=no" /etc/sysconfig/network-scripts/ifcfg-eth0
  sed -i -e "/IPV6_AUTOCONF.*/d;$ a IPV6_AUTOCONF=no" /etc/sysconfig/network-scripts/ifcfg-eth0
  sed -i -e "/IPV6_DEFROUTE.*/d;$ a IPV6_DEFROUTE=no" /etc/sysconfig/network-scripts/ifcfg-eth0
  sed -i -e "/IPV6_PEERDNS.*/d;$ a IPV6_PEERDNS=no" /etc/sysconfig/network-scripts/ifcfg-eth0
  sed -i -e "/IPV6_PEERROUTES.*/d;$ a IPV6_PEERROUTES=no" /etc/sysconfig/network-scripts/ifcfg-eth0
  sed -i -e "/IPV6FORWARDING.*/d;$ a IPV6FORWARDING=no" /etc/sysconfig/network-scripts/ifcfg-eth0
  sed -i -e "/IPV6_AUTOTUNNEL.*/d;$ a IPV6_AUTOTUNNEL=no" /etc/sysconfig/network-scripts/ifcfg-eth0

  # Ensure good DNS servers are being used, and NM will be in control.
  sed -i -e "/NM_CONTROLLED/d" /etc/sysconfig/network-scripts/ifcfg-eth0
  printf "PEERDNS=\"no\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  printf "NM_CONTROLLED=\"yes\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  printf "IPV4_FAILURE_FATAL=\"no\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  printf "DNS1=4.2.2.1\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  printf "DNS2=4.2.2.2\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
fi

# Depending on the kick start configuration, the NetworkManager may still
# need to be installed. We'll take care of that here, since we rely it
# to handle disconnected, and/or missintg ethernet iterfaces gracefully.
#retry yum install --assumeyes NetworkManager

# If postfix is installed, configure it use only ipv4 interfaces, or it will fail to start properly.
if [ -f /etc/postfix/main.cf ]; then
  sed -i "s/^inet_protocols.*$/inet_protocols = ipv4/g" /etc/postfix/main.cf
fi

# Prevent udev from persisting the network interface rules.
[ -f /etc/udev/rules.d/70-persistent-net.rules ] && rm -f /etc/udev/rules.d/70-persistent-net.rules
sed -i -e 's/\(\[ "\$comment" \] && echo "# \$comment"\)/# \1/g' /lib/udev/write_net_rules
sed -i -e 's/\(echo "SUBSYSTEM==\\\"net\\\", ACTION==\\\"add\\\"\$match, NAME\=\\\"\$name\\\""\)/# \1/g' /lib/udev/write_net_rules

# Time to reboot.
(shutdown -r +1) &
exit 0

