#!/bin/bash -eux

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/sshd
sed -i -e "s/\(.*pam_motd.so.*noupdate.*\)/# \1/g" /etc/pam.d/sshd

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/login
sed -i -e "s/\(.*pam_motd.so.*noupdate.*\)/# \1/g" /etc/pam.d/loginc/pam.d/login

cat <<-EOF > /etc/motd
EOF
