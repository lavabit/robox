#!/bin/bash

# Delete the OpenSSH host keys, so they get generated when the box is
# provisioned.

rm -f /etc/ssh/ssh_host_key
rm -f /etc/ssh/ssh_host_key.pub

rm -f /etc/ssh/ssh_host_dsa_key
rm -f /etc/ssh/ssh_host_dsa_key.pub

rm -f /etc/ssh/ssh_host_rsa_key
rm -f /etc/ssh/ssh_host_rsa_key.pub

rm -f /etc/ssh/ssh_host_ecdsa_key
rm -f /etc/ssh/ssh_host_ecdsa_key.pub

rm -f /etc/ssh/ssh_host_ed25519_key
rm -f /etc/ssh/ssh_host_ed25519_key.pub

if [[ "$PACKER_BUILD_NAME" =~ ^.*(ubuntu|debian|lineage).*$ ]]; then
  printf "@reboot root command bash -c 'export PATH=$PATH:/usr/sbin ; export DEBIAN_FRONTEND=noninteractive ; export DEBCONF_NONINTERACTIVE_SEEN=true ; /usr/sbin/dpkg-reconfigure openssh-server &>/dev/null ; /bin/systemctl restart ssh.service ; rm --force /etc/cron.d/keys'\n" > /etc/cron.d/keys
elif [[ "$PACKER_BUILD_NAME" =~ ^.*(devuan).*$ ]]; then
  printf "@reboot root command bash -c 'export PATH=$PATH:/usr/sbin ; export DEBIAN_FRONTEND=noninteractive ; export DEBCONF_NONINTERACTIVE_SEEN=true ; /usr/sbin/dpkg-reconfigure openssh-server &>/dev/null ; /usr/sbin/service ssh restart ; rm --force /etc/cron.d/keys'\n" > /etc/cron.d/keys
fi
