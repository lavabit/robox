#!/bin/bash -ux

# Sudo should already be installed, but just in case.
pkg_add -I sudo--

# Setup the default user password and ensure the vagrant shell is bash.
PASSWD=$(echo "vagrant" | encrypt -b 6)
adduser -batch vagrant vagrant
usermod -p $PASSWD vagrant
chsh -s bash vagrant

#Defaults:vagrant !requiretty

cat <<-EOF > /usr/local/etc/sudoers.d/vagrant
vagrant ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /usr/local/etc/sudoers.d/vagrant

# Create the vagrant user ssh directory.
mkdir -pm 700 /home/vagrant/.ssh

# Create an authorized keys file and insert the insecure public vagrant key.
cat <<-EOF > /home/vagrant/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
EOF

# Ensure the permissions are set correct to avoid OpenSSH complaints.
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Mark the vagrant box build time.
date > /etc/vagrant_box_build_time
