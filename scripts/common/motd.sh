#!/bin/bash -ux

if [ -f /etc/os-release ]; then
source /etc/os-release
cat << EOF > /etc/motd
$PRETTY_NAME ($VERSION_ID)
EOF
else
cat << EOF > /etc/motd
EOF
fi
