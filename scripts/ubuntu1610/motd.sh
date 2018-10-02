#!/bin/bash -eux

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/sshd
sed -i -e "s/\(.*pam_motd.so.*noupdate.*\)/# \1/g" /etc/pam.d/sshd

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/login
sed -i -e "s/\(.*pam_motd.so.*noupdate.*\)/# \1/g" /etc/pam.d/login

mkdir -p /root/.cache/
touch /root/.cache/motd.legal-displayed

if [ -d /home/vagrant/ ]; then
  mkdir -p /home/vagrant/.cache/
  touch /home/vagrant/.cache/motd.legal-displayed
  chown vagrant:vagrant /home/vagrant/.cache/ 
  chown vagrant:vagrant /home/vagrant/.cache/motd.legal-displayed
fi

cat <<-EOF > /etc/motd
EOF
