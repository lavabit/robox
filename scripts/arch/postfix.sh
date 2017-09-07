#!/bin/bash -eux

# Update the package database.
pacman --sync --noconfirm postfix libmariadbclient lzo postgresql-libs tinycdb

# Update the system packages.
pacman --sync --noconfirm --refresh --sysupgrade

# Configure postfix to listen for relays on port 2525 so it doesn't conflict with magma.
sed -i -e "s/^smtp\([ ]*inet\)/127.0.0.1:2525\1/" /etc/postfix/master.cf

# Configure the postfix hostname and origin parameters.
printf "\ninet_interfaces = localhost\n" >> /etc/postfix/main.cf
printf "myhostname = relay.magma.builder\n" >> /etc/postfix/main.cf
printf "myorigin = magma.builder\n" >> /etc/postfix/main.cf
printf "transport_maps = hash:/etc/postfix/transport\n" >> /etc/postfix/main.cf

# printf "magma.builder         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
# postmap /etc/postfix/transport

# Setup postfix to start automatically.
systemctl start postfix.service && systemctl enable postfix.service
