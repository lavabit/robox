#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# Disable IPv6 for the current boot.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure IPv6 stays disabled.
printf "\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^generic-ubuntu1904-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "ubuntu1904.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 ubuntu1904.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi

cat <<-EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      optional: true
      nameservers:
        addresses: [4.2.2.1, 4.2.2.2, 208.67.220.220]
EOF

# Apply the network plan configuration.
netplan generate

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
sed -i -e "s/#DNS=.*/DNS=4.2.2.1 4.2.2.2 208.67.220.220/g" /etc/systemd/resolved.conf
sed -i -e "s/#FallbackDNS=.*/FallbackDNS=/g" /etc/systemd/resolved.conf
sed -i -e "s/#Domains=.*/Domains=/g" /etc/systemd/resolved.conf
sed -i -e "s/#DNSSEC=.*/DNSSEC=yes/g" /etc/systemd/resolved.conf
sed -i -e "s/#Cache=.*/Cache=yes/g" /etc/systemd/resolved.conf
sed -i -e "s/#DNSStubListener=.*/DNSStubListener=yes/g" /etc/systemd/resolved.conf

# Install ifplugd so we can monitor and auto-configure nics.
retry apt-get --assume-yes install ifplugd

# Configure ifplugd to monitor the eth0 interface.
sed -i -e 's/INTERFACES=.*/INTERFACES="eth0"/g' /etc/default/ifplugd

# Ensure the networking interfaces get configured on boot.
systemctl enable systemd-networkd.service

# Ensure ifplugd also gets started, so the ethernet interface is monitored.
systemctl enable ifplugd.service

# Reboot onto the new kernel (if applicable).
$(shutdown -r +1) &
