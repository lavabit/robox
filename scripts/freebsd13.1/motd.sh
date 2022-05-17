#!/bin/bash -eux

sed -i "" -e "s/update_motd=\"YES\"/update_motd=\"NO\"/g" /etc/defaults/rc.conf

cat << EOF > /etc/motd
EOF
