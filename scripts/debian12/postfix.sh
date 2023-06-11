#!/bin/bash -eux

# Configure postfix to listen for relays on port 2525 so it doesn't conflict with magma.
sed -i -e "s/^smtp\([ ]*inet\)/127.0.0.1:2525\1/" /etc/postfix/master.cf

# Copy over the default debian postfix config file.
cp /usr/share/postfix/main.cf.debian /etc/postfix/main.cf

# Configure the postfix hostname and origin parameters.
printf "\ninet_interfaces = localhost\n" >> /etc/postfix/main.cf
printf "inet_protocols = ipv4\n" >> /etc/postfix/main.cf
printf "myhostname = relay.magma.localdomain\n" >> /etc/postfix/main.cf
printf "myorigin = magma.localdomain\n" >> /etc/postfix/main.cf
printf "transport_maps = hash:/etc/postfix/transport\n" >> /etc/postfix/main.cf
printf "queue_directory = /var/spool/postfix\n" >> /etc/postfix/main.cf
printf "mynetworks = 127.0.0.0/8\n" >> /etc/postfix/main.cf
printf "mydestination = \$myhostname, localhost.\$mydomain, localhost\n" >> /etc/postfix/main.cf

printf "magma.localdomain         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
postmap /etc/postfix/transport

# So it gets started automatically.
systemctl enable postfix.service && systemctl start postfix.service
