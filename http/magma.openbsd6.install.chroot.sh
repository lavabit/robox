#!/bin/sh

set -e
set -x

pkg_add bash sudo--
mkdir /etc/sudoers.d
sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

cat <<EOF > /etc/sudoers
includedir /etc/sudoers.d
EOF

cat <<EOF > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty
vagrant ALL=(ALL) NOPASSWD: ALL
EOF

cat <<EOF > /etc/sudoers.d/root
Defaults:root !requiretty
root ALL=(ALL) NOPASSWD: ALL
EOF

chmod 440 /etc/sudoers.d/root
chmod 440 /etc/sudoers.d/vagrant
