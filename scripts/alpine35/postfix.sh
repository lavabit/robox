#!/bin/bash -eux

# The postfix server for message relays.
apk add postfix db libsasl

# Configure postfix to listen for relays on port 2525 so it doesn't conflict with magma.
sed -i -e "s/^smtp\([ ]*inet\)/127.0.0.1:2525\1/" /etc/postfix/master.cf

# Configure the postfix hostname and origin parameters.
printf "\ninet_interfaces = localhost\n" >> /etc/postfix/main.cf
printf "inet_protocols = ipv4\n" >> /etc/postfix/main.cf
printf "myhostname = relay.magma.builder\n" >> /etc/postfix/main.cf
printf "myorigin = magma.builder\n" >> /etc/postfix/main.cf
printf "transport_maps = hash:/etc/postfix/transport\n" >> /etc/postfix/main.cf

# printf "magma.builder         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
# postmap /etc/postfix/transport

# So it gets started automatically.
rc-update add postfix default && rc-service postfix start
