#!/bin/bash

printf "Harden the SSHD Configuration.\n"

# Tweak sshd to prevent reverse DNS lookups which speeds up the login process.
sed -i -e "s/^#\(UseDNS\) yes$/\1 no/g" /etc/ssh/sshd_config
sed -i -e "s/^\(PasswordAuthentication\) yes$/\1 no/g" /etc/ssh/sshd_config

# This option will also disable DNS lookups.
printf "\nOPTIONS=\"-u0\"\n\n" >> /etc/sysconfig/sshd

# We want our sshd host keys to be stronger than the default value. This will force sshd to  
# use a stronger entropy source. It requires an entropy daemon like haveged or connections 
# will experience massive delays while they wait for the kernel to collect enough entropy. 
# It will also ensure we only generate ssh protocol version 2 RSA host keys.
sed --in-place "s/export SSH_USE_STRONG_RNG=0/export SSH_USE_STRONG_RNG=1024/g" /etc/sysconfig/sshd
sed --in-place "s/AUTOCREATE_SERVER_KEYS=YES/# AUTOCREATE_SERVER_KEYS=YES/g" /etc/sysconfig/sshd
sed --in-place "s/# AUTOCREATE_SERVER_KEYS=RSAONLY/AUTOCREATE_SERVER_KEYS=RSAONLY/g" /etc/sysconfig/sshd

# This will update the init script so when it goes to autogenerate the host keys, they are 
# 4096 bits, instead of the default.
sed --in-place "s/\$KEYGEN/\$KEYGEN -b 4096/g" /etc/init.d/sshd

# We uncomment the RSA host key path in the sshd config to avoid complaints about the missing DSA host key.
sed --in-place "s/#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/g" /etc/ssh/sshd_config

# Finally we are going to delete the existing host keys so they get recreated during the next reboot 
# cycle.
rm --force /etc/ssh/ssh_host_key /etc/ssh/ssh_host_key.pub
rm --force /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub
rm --force /etc/ssh/ssh_host_dsa_key /etc/ssh/ssh_host_dsa_key.pub

# Generate a new stronger host key.
/usr/bin/ssh-keygen -q -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -C '' -N ''
chgrp ssh_keys /etc/ssh/ssh_host_rsa_key
chmod 640 /etc/ssh/ssh_host_rsa_key
chmod 644 /etc/ssh/ssh_host_rsa_key.pub
chcon system_u:object_r:sshd_key_t:s0 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub



