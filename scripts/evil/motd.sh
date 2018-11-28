#!/bin/bash -eux

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/sshd 

cat << EOF > /etc/motd
EOF
