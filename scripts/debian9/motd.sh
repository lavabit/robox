#!/bin/bash -eux

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/sshd 
sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/login

cat << EOF > /etc/motd
EOF
